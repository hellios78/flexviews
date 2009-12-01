#!/usr/local/bin/php
<?php
error_reporting(E_ALL);

if(count($argv) != 4) {
  echo "usage: {$argv[0]} /path/to/inifile \"master-log-file\" master-log-pos\n";
  echo "for example: {$argv[0]} \"master-log.000001\" 123456\n";
  exit;
}

$iniFile = $argv[1];

$mvlogList = array();

$settings=@parse_ini_file($iniFile,true) or die("Could not read ini file: $iniFile\n");
if(!$settings || empty($settings['flexviews'])) {
  die("Could not find [flexviews] section or .ini file not found");
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

mysql_query("BEGIN;", $dest);
$sql = "UPDATE flexviews.binlog_consumer_status bcs set exec_master_log_pos = master_log_size where server_id={$serverId} AND master_log_file < '{$argv[2]}'";
$stmt = mysql_query($sql, $dest) or die($sql . "\n" . mysql_error() . "\n");

$sql = "UPDATE flexviews.binlog_consumer_status bcs set exec_master_log_pos = {$argv[3]} where server_id={$serverId} AND master_log_file = '{$argv[2]}'";
$stmt = mysql_query($sql, $dest) or die($sql . "\n" . mysql_error() . "\n");
mysql_query("commit;", $dest);



