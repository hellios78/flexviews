#!/usr/local/bin/php
<?php

if(!empty($argv[1])) {
  $iniFile = $argv[1];
} else {
  $iniFile = "./consumer.ini";
}

error_reporting(E_ALL);

$mvlogList = array();

$settings=@parse_ini_file($iniFile,true) or die("Could not read ini file: $iniFile\n");
if(!$settings || empty($settings['flexviews'])) {
  die("Could not find [flexviews] section or .ini file not found");
}

#the mysqlbinlog command line starts with the 
if(!empty($settings['flexviews']['mysqlbinlog'])) {
	$cmdLine = $settings['flexviews']['mysqlbinlog'];
} else {
	$cmdLine = 'mysqlbinlog';
}

foreach($settings['source'] as $k => $v) {
  $cmdLine .= " --$k=$v";
}

$S = $settings['source'];
$D = $settings['dest'];

$source = mysql_connect($S['host'] . ':' . $S['port'], $S['user'], $S['password']) or die('Could not connect to MySQL server:' . mysql_error());
$dest = mysql_connect($D['host'] . ':' . $D['port'], $D['user'], $D['password']) or die('Could not connect to MySQL server:' . mysql_error());
mysql_query("USE flexviews",$dest);
mysql_query("BEGIN;", $dest) or die(mysql_error());
mysql_query("CREATE TEMPORARY table flexviews.log_list (log_name char(50), primary key(log_name))",$dest) or die(mysql_error());

$sql = "SELECT @@server_id";
$stmt = mysql_query($sql, $source);
$row = mysql_fetch_array($stmt) or die($sql . "\n" . mysql_error() . "\n");
$serverId = $row[0];

$stmt = mysql_query("SET SQL_LOG_BIN=0", $dest);
if(!$stmt) die(mysql_error());

/* RUN THIS ON THE SOURCE DATABASE*/
$stmt = mysql_query("SHOW BINARY LOGS", $source);
if(!$stmt) die(mysql_error());

while($row = mysql_fetch_array($stmt)) {
  $sql = sprintf("INSERT INTO flexviews.binlog_consumer_status (server_id, master_log_file, master_log_size, exec_master_log_pos) values ($serverId, '%s', %d, 0) ON DUPLICATE KEY UPDATE master_log_size = %d ;", $row['Log_name'], $row['File_size'], $row['File_size']);

  mysql_query($sql, $dest) or die($sql . "\n" . mysql_error() . "\n");

  $sql = sprintf("INSERT INTO log_list (log_name) values ('%s')", $row[0]);
  mysql_query($sql, $dest) or die($sql . "\n" . mysql_error() . "\n");
}
mysql_query("commit", $dest) or die("could not commit\n" . mysql_error() . "\n");

// TODO Detect if this is going to purge unconsumed logs as this means we either fell behind log cleanup, the master was reset or something else VERY BAD happened!
$sql = "DELETE bcs.* FROM flexviews.binlog_consumer_status bcs where server_id=$serverId AND master_log_file not in (select log_name from log_list)";
mysql_query($sql, $dest) or die($sql . "\n" . mysql_error() . "\n");

$sql = "DROP TEMPORARY table log_list";
mysql_query($sql, $dest) or die("Could not drop TEMPORARY TABLE log_list\n");

$sql = "SELECT bcs.* from flexviews.binlog_consumer_status bcs where server_id=$serverId AND exec_master_log_pos < master_log_size order by master_log_file;";

#get the list of tables to mvlog from the database
refresh_mvlog_cache();

echo " -- Finding binary logs to process\n";
$stmt = mysql_query($sql, $dest) or die($sql . "\n" . mysql_error() . "\n");
$processedLogs = 0;
while($row = mysql_fetch_assoc($stmt)) {
  ++$processedLogs;

  if ($row['exec_master_log_pos'] < 4) $row['exec_master_log_pos'] = 4;
  $execCmdLine = sprintf("%s -v -R --start-position=%d --stop-position=%d %s", $cmdLine, $row['exec_master_log_pos'], $row['master_log_size'], $row['master_log_file']);
  echo  "-- $execCmdLine\n";
  $proc = popen($execCmdLine, "r");
  process_binlog($proc, $row['master_log_file'], $row['exec_master_log_pos']);
  pclose($proc);

}

exit($processedLogs);

function process_binlog($proc,$logName, $binlogPosition) {
  static $mvlogDB = false;
  $newTransaction = true;
  global $mvlogList;
  global $source, $dest;
  global $serverId;
  $timeStamp = false;

  refresh_mvlog_cache();
  $sql = "";
  
  $valList = "";
  $oldTable = "";

  if(!$mvlogDB) {
    $stmt = mysql_query("SELECT flexviews.get_setting('mvlog_db')", $dest) or die ("Could not determine mvlog DB\n" . mysql_error());
    $row = mysql_fetch_array($stmt);
    $mvlogDB = $row[0];
  }
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

    $matches = array();

    if($prefix[0] == "#") {
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
          if(preg_match('/^#([0-9: ]+).*\s+end_log_pos ([0-9]+)/', $line,$matches)) {

            $binlogPosition = $matches[2];
  	    if(!$timeStamp) { 
               new_uow($binlogPosition, $matches[1], $serverId, $logName);
            }
            $timeStamp = $matches[1];
          }
      }  
    }

    if($prefix=="# End" || ($prefix == "COMMI" && substr($line, 0, 6) == "COMMIT"))  {
      new_uow($binlogPosition, $timeStamp, $serverId, $logName);
    }

  }

}

function new_uow($binlogPosition, $timeStamp, $serverId, $logName) {
global $source, $dest;
       mysql_query("START TRANSACTION", $dest) or die("COULD NOT START TRANSACTION;\n" . mysql_error());

       $sql = sprintf("UPDATE flexviews.binlog_consumer_status set exec_master_log_pos = %d where master_log_file = '%s' and server_id = $serverId", $binlogPosition, $logName);
       mysql_query($sql, $dest) or die("COULD NOT EXEC:\n$sql\n" . mysql_error());

       $sql = sprintf("INSERT INTO flexviews.mview_uow values(NULL,str_to_date('%s', '%%y%%m%%d %%H:%%i:%%s'));",rtrim($timeStamp));
       mysql_query($sql,$dest) or die("COULD NOT CREATE NEW UNIT OF WORK:\n$sql\n" .  mysql_error());
       echo "$sql\n";

       $sql = "SET @fv_uow_id := LAST_INSERT_ID();";
       mysql_query($sql, $dest) or die("COULD NOT EXEC:\n$sql\n" . mysql_error());
}

function process_rowlog($proc, &$db, &$table, &$serverId, &$mvLogDB) {
  $sql = "";
  $valList = "";
  $line = "";
  global $source, $dest;

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
           mysql_query($sql, $dest) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_error());
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
        mysql_query($sql, $dest) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_query());
        $valList = "";
	break; 
    }
  }
  #return the last line so that we can process it in the parent body
  return $line;
}

function refresh_mvlog_cache() {
  global $mvlogList;
  global $source,$dest;

  $mvlogList = array();

  $sql = "SELECT table_schema, table_name from flexviews.mvlogs where active_flag=1";
  $stmt = mysql_query($sql, $dest);
  while($row = mysql_fetch_array($stmt)) {
    $mvlogList[$row[0] . $row[1]] = 1;
  }


}


