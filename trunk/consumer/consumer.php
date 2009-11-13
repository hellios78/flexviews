#!/usr/bin/php
<?php
error_reporting(E_ALL);

$mvlogList = array();

$settings=parse_ini_file('consumer.ini',true);
if(!$settings || empty($settings['flexviews'])) {
  die("Could not find [flexviews] section or .ini file not found");
}

#the mysqlbinlog command line starts with the 
if(!empty($settings['flexviews']['mysqlbinlog'])) {
	$cmdLine = $settings['flexviews']['mysqlbinlog'];
} else {
	$cmdLine = 'mysqlbinlog';
}

foreach($settings['consumer'] as $k => $v) {
  $cmdLine .= " --$k=$v";
}

$S = $settings['consumer'];

$conn = mysql_connect($S['host'] . ':' . $S['port'], $S['user'], $S['password']) or die('Could not connect to MySQL server:' . mysql_error());
mysql_query("USE flexviews",$conn);
mysql_query("BEGIN;", $conn) or die(mysql_error());
mysql_query("CREATE TEMPORARY table flexviews.log_list (log_name char(50), primary key(log_name))",$conn) or die(mysql_error());

$stmt = mysql_query("SET SQL_LOG_BIN=0");
if(!$stmt) die(mysql_error());

$stmt = mysql_query("SHOW BINARY LOGS");
if(!$stmt) die(mysql_error());

while($row = mysql_fetch_array($stmt)) {

  $sql = sprintf("INSERT INTO flexviews.binlog_consumer_status (master_log_file, master_log_size, exec_master_log_pos) values ('%s', %d, 0) ON DUPLICATE KEY UPDATE master_log_size = %d ;", $row[0], $row[1], $row[1]);
  mysql_query($sql, $conn) or die($sql . "\n" . mysql_error() . "\n");

  $sql = sprintf("INSERT INTO log_list (log_name) values ('%s')", $row[0]);
  mysql_query($sql, $conn) or die($sql . "\n" . mysql_error() . "\n");
}

// TODO Detect if this is going to purge unconsumed logs as this means we either fell behind log cleanup, the master was reset or something else VERY BAD happened!
$sql = "DELETE bcs.* FROM flexviews.binlog_consumer_status bcs where master_log_file not in (select log_name from log_list)";
mysql_query($sql, $conn) or die($sql . "\n" . mysql_error() . "\n");

$sql = "DROP TEMPORARY table log_list";
mysql_query($sql, $conn) or die("Could not drop TEMPORARY TABLE log_list\n");



$sql = "SELECT bcs.* from flexviews.binlog_consumer_status bcs where exec_master_log_pos < master_log_size order by master_log_file;";

#get the list of tables to mvlog from the database
refresh_mvlog_cache();

echo " -- Finding binary logs to process\n";
$stmt = mysql_query($sql, $conn) or die($sql . "\n" . mysql_error() . "\n");
while($row = mysql_fetch_array($stmt)) {
  if ($row[2] < 4) $row[2] = 4;
  $execCmdLine = sprintf("%s -v -R --start-position=%d --stop-position=%d %s", $cmdLine, $row[2], $row[1], $row[0]);
  echo sprintf(" -- PROCESS BINARY LOG: %s, size:%d, exec_at:%d, exec_to:%d\n", $row[0], $row[1], $row[2], $row[1]);
  echo  "-- $execCmdLine\n";
  $proc = popen($execCmdLine, "r");
  process_binlog($proc, $row[0]);
  pclose($proc);
}


function process_binlog($proc,$logName) {
  $newTransaction = true;
  global $mvlogList;
  refresh_mvlog_cache();
  $sql = "";
  
  $serverId = 0;

  $valList = "";
  $oldTable = "";

  $stmt = mysql_query("SELECT flexviews.get_setting('mvlog_db')") or die ("Could not determine mvlog DB\n" . mysql_error());
  $row = mysql_fetch_array($stmt);
  $mvlogDB = $row[0];
  $binlogPosition = 4;
  $lastLine = "";
 
  while( !feof($proc) ) { 
    if($lastLine) {
      $line = $lastLine;
       $lastLine = "";
    } else {
      $line = trim(fgets($proc));
    }
  
    #echo "-- $line\n";

    $prefix=substr($line, 0, 5);

    #ASSUMPTION: server_id never changes in the middle of a binlog
    if (!$serverId && preg_match('/\s+server id ([0-9]+)\s/', $line, $matches)) {
      $serverId = $matches[1]; 
    }

    $matches = array();

    if($prefix=="SET T") {
      $matches = explode('=', $line);
      $timeStamp = $matches[1]; 
    }elseif($prefix[0] == "#") {
      if($prefix == "### I" || $prefix == "### U" || $prefix == "### D") {
        if(preg_match('/### (UPDATE|INSERT INTO|DELETE FROM)\s([^.]+)\.(.*$)/', $line, $matches)) {
  	  $db = $matches[2];
          $table = $matches[3] . '_mvlog';
          $base_table = $matches[3];

          if($db == 'flexviews' && $table == 'mvlogs') {
            refresh_mvlog_cache();
          }

          if(!empty($mvlogList[$db . $base_table])) {
	    $lastLine = process_rowlog($proc, $db, $table, $serverId, $mvlogDB);
            continue;
          }
        }
      }else {
          if(preg_match('/\s+end_log_pos ([0-9]+)/', $line,$matches)) {
            $sql = sprintf("UPDATE flexviews.binlog_consumer_status set exec_master_log_pos = %d where master_log_file = '%s'", $matches[1], $logName);
            $binlogPosition = $matches[1];
            mysql_query($sql) or die("Could not update binlog_consumer_status:\n$sql\n" . mysql_error());
          }
      }  
    }
    if($prefix == "BEGIN" || substr($line, 0, 6) == "COMMIT")  {
       $sql = "START TRANSACTION;";
       mysql_query($sql) or die("COULD NOT BEGIN NEW TRANSACTION:\n" . mysql_error());

       $sql = sprintf("INSERT INTO flexviews.mview_uow values(NULL,from_unixtime(%d));",$timeStamp);
       mysql_query($sql) or die("COULD NOT CREATE NEW UNIT OF WORK:\n$sql\n" .  mysql_error());

       $sql = "SET @fv_uow_id := LAST_INSERT_ID();";
       mysql_query($sql) or die("COULD NOT EXEC:\n$sql\n" . mysql_error());

    }

  }

}

function process_rowlog($proc, &$db, &$table, &$serverId, &$mvLogDB) {
  $sql = "";
  $valList = "";
  $line = "";
  # loop over the input, collecting all the input values into a set of INSERT statements
  while($line = fgets($proc)) {
    #echo "***$line";
    $line = trim($line);
    if($line == "### WHERE") {
      $valList .= "(-1, @fv_uow_id, $serverId";
      $sql = sprintf("INSERT INTO %s.`%s` VALUES ", $mvLogDB, $table, $serverId);
    } elseif($line == "### SET")  {
        if ($valList) {
           $sql .= $valList . ")";
           mysql_query($sql) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_error());
        }

        $valList = "(1, @fv_uow_id, $serverId";
        $sql = sprintf("INSERT INTO %s.`%s` VALUES ", $mvLogDB, $table, $serverId);
    } elseif(preg_match('/###\s+@[0-9]+=(.*)$/', $line, $matches)) {
        $val = ltrim($matches[1],"'");
        $val = rtrim($val,"'");
        $valList .= ',\'' . $val . '\'';
    } else {
	#we are done collecting records for the update, so exit the loop
	$sql .= $valList . ")";
        mysql_query($sql) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_query());
        $valList = "";
	break; 
    }
  }
  #return the last line so that we can process it in the parent body
  return $line;
}

function refresh_mvlog_cache() {
  global $mvlogList;
  $mvlogList = array();

  $sql = "SELECT table_schema, table_name from flexviews.mvlogs where active_flag=1";
  $stmt = mysql_query($sql);
  while($row = mysql_fetch_array($stmt)) {
    $mvlogList[$row[0] . $row[1]] = 1;
  }


}


