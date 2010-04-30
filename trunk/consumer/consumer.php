#!/usr/local/bin/php
<?php
error_reporting(E_ALL);

class FlexConsumer {
	private	$mvlogList = array();
	private $settings = array();
	private $onlyDatabases = array();
	private $cmdLine;

	private $source = NULL;
	private $dest = NULL;

	private $serverId = NULL;
	
	private $binlogServerId;
	
	public  $raiseWarnings = true;
	
	#Construct a new consumer object.
	#By default read settings from the INI file unless they are passed
	#into the constructor	
	public function __construct($settings = NULL) {
		if($settings) {
			$this->settings = $settings;	
		} else {
			$this->read_settings();
		}
		if(!$this->cmdLine) $this->cmdLine = `which mysqlbinlog`;
		
		#only record changelogs from certain databases?
		if(!empty($this->settings['flexviews']['only_database'])) {
			$vals = explode(',', $this->settings['flexviews']['only_databases']);
			foreach($vals as $val) {
				$this->onlyDatabases[] = trim($val);
			}
		}
		
		#the mysqlbinlog command line location may be set in the settings
		#we will autodetect the location if it is not specified explicitly
		if(!empty($this->settings['flexviews']['mysqlbinlog'])) {
			$this->cmdLine = $this->settings['flexviews']['mysqlbinlog'];
		} 
		
		#build the command line from user, host, password, socket options in the ini file in the [source] section
		foreach($this->settings['source'] as $k => $v) {
			$this->cmdLine .= " --$k=$v";
		}
		
		#shortcuts
		$S = $this->settings['source'];
		$D = $this->settings['dest'];
	
		/*TODO: support unix domain sockets */
		$this->source = mysql_connect($S['host'] . ':' . $S['port'], $S['user'], $S['password']) or die('Could not connect to MySQL server:' . mysql_error());
		$this->dest = mysql_connect($D['host'] . ':' . $D['port'], $D['user'], $D['password']) or die('Could not connect to MySQL server:' . mysql_error());
	
	}
	
	public function capture_changes() {
				
		$this->initialize_dest();
		$this->get_source_logs();
		$this->cleanup_logs();
				
		$sql = "SELECT bcs.* 
		          FROM flexviews.binlog_consumer_status bcs 
		         where server_id=$serverId 
		           AND exec_master_log_pos < master_log_size 
		         order by master_log_file;";
		
		echo " -- Finding binary logs to process\n";
		$stmt = mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");
		$processedLogs = 0;
		while($row = mysql_fetch_assoc($stmt)) {
			++$processedLogs;
		
			if ($row['exec_master_log_pos'] < 4) $row['exec_master_log_pos'] = 4;
			$execCmdLine = sprintf("%s --base64-output=decode-rows -v -R --start-position=%d --stop-position=%d %s", $this->cmdLine, $row['exec_master_log_pos'], $row['master_log_size'], $row['master_log_file']);
			echo  "-- $execCmdLine\n";
			$proc = popen($execCmdLine, "r");
			$this->binlogPosition = $row['exec_master_log_pos'];
			$this->logName = $row['master_log_file'];
			$this->process_binlog($proc, $row['master_log_file'], $row['exec_master_log_pos']);
			#make sure the end of the binary log is captured
			$this->set_capture_pos();
			pclose($proc);
		}
		
		return $processedLogs;

	}
	
	private function read_settings() {
		if(!empty($argv[1])) {
			$iniFile = $argv[1];
		} else {
			$iniFile = "./consumer.ini";
		}
	
		$this->settings=@parse_ini_file($iniFile,true) or die("Could not read ini file: $iniFile\n");
		if(!$this->settings || empty($this->settings['flexviews'])) {
			die("Could not find [flexviews] section or .ini file not found");
		}


	
	}

	
	private function refresh_mvlog_cache() {
		$this->mvlogList = array();
			
		$sql = "SELECT table_schema, table_name, mvlog_name from flexviews.mvlogs where active_flag=1";
		$stmt = mysql_query($sql, $this->dest);
		while($row = mysql_fetch_array($stmt)) {
			$this->mvlogList[$row[0] . $row[1]] = $row[3];
		}
	}
	
	/* Set up the destination connection */
	function initialize_dest() {
		mysql_query("USE flexviews",$this->dest);
		mysql_query("BEGIN;", $this->dest) or die(mysql_error());
		mysql_query("CREATE TEMPORARY table flexviews.log_list (log_name char(50), primary key(log_name))",$this->dest) or die(mysql_error());
	

	
		$stmt = mysql_query("SET SQL_LOG_BIN=0", $this->dest);
		if(!$stmt) die(mysql_error());
		
		$stmt = mysql_query("SELECT flexviews.get_setting('mvlog_db')", $dest) or die ("Could not determine mvlog DB\n" . mysql_error());
		$row = mysql_fetch_array($stmt);
		$this->mvlogDB = $row[0];
		
	}
	
	/* Get the list of logs from the source and place them into a temporary table on the dest*/
	function get_source_logs() {
		/* This server id is not related to the server_id in the log.  It refers to the ID of the 
		 * machine we are reading logs from.
		 */
		$sql = "SELECT @@server_id";
		$stmt = mysql_query($sql, $this->source);
		$row = mysql_fetch_array($stmt) or die($sql . "\n" . mysql_error() . "\n");
		$this->serverId = $row[0];
		
		$stmt = mysql_query("SHOW BINARY LOGS", $this->source);
		if(!$stmt) die(mysql_error());
	
		while($row = mysql_fetch_array($stmt)) {
			$sql = sprintf("INSERT INTO flexviews.binlog_consumer_status (server_id, master_log_file, master_log_size, exec_master_log_pos) values ($serverId, '%s', %d, 0) ON DUPLICATE KEY UPDATE master_log_size = %d ;", $row['Log_name'], $row['File_size'], $row['File_size']);
			mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");
	
			$sql = sprintf("INSERT INTO log_list (log_name) values ('%s')", $row[0]);
			mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");
		}
	}
	
	/* Remove any logs that have gone away */
	function cleanup_logs() {
		// TODO Detect if this is going to purge unconsumed logs as this means we either fell behind log cleanup, the master was reset or something else VERY BAD happened!
		$sql = "DELETE bcs.* FROM flexviews.binlog_consumer_status bcs where server_id={$this->serverId} AND master_log_file not in (select log_name from log_list)";
		mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");

		$sql = "DROP TEMPORARY table log_list";
		mysql_query($sql, $this->dest) or die("Could not drop TEMPORARY TABLE log_list\n");
	}

	function set_capture_pos() {
		$sql = sprintf("UPDATE flexviews.binlog_consumer_status set exec_master_log_pos = %d where master_log_file = '%s' and server_id = %d",$this->serverId, $this->binlogPosition, $this->logName);
		mysql_query($sql, $dest) or die("COULD NOT EXEC:\n$sql\n" . mysql_error());
		
	}

	/* Called when a new transaction starts*/
	function start_transaction() {
		mysql_query("START TRANSACTION", $this->dest) or die("COULD NOT START TRANSACTION;\n" . mysql_error());
        $this->set_capture_pos();
		$sql = sprintf("INSERT INTO flexviews.mview_uow values(NULL,str_to_date('%s', '%%y%%m%%d %%H:%%i:%%s'));",rtrim($this->timeStamp));
		mysql_query($sql,$dest) or die("COULD NOT CREATE NEW UNIT OF WORK:\n$sql\n" .  mysql_error());
		 
		$sql = "SET @fv_uow_id := LAST_INSERT_ID();";
		mysql_query($sql, $dest) or die("COULD NOT EXEC:\n$sql\n" . mysql_error());

	}

    /* Called when a transaction commits */
	function commit_transaction() {
		$this->set_capture_pos();
		mysql_query("COMMIT", $this->dest) or die("COULD NOT COMMIT TRANSACTION;\n" . mysql_error());
	}

	/* Called when a transaction rolls back */
	function rollback_transaction() {
		mysql_query("ROLLBACK", $this->dest) or die("COULD NOT ROLLBACK TRANSACTION;\n" . mysql_error());
		#update the capture position and commit, because we don't want to keep reading a rolled back 
		#transaction in the log, if it is the last thing in the log
		$this->set_capture_pos();
		mysql_query("COMMIT", $this->dest) or die("COULD NOT COMMIT TRANSACTION LOG POSITION UPDATE;\n" . mysql_error());
		
	}

	/* Called when a row is deleted, or for the old image of an UPDATE */
	function delete_row($mvLogDB, $mvLogTable, $row = array()) {
		$valList .= "(1, @fv_uow_id, {$this->serverId}," . implode(",", $row) . ")";
		$sql = sprintf("INSERT INTO %s.`%s` VALUES %s", $mvLogDB, $mvLogTable, $valList );
		mysql_query($sql, $dest) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_error());
	}

	/* Called when a row is inserted, or for the new image of an UPDATE */
	function insert_row($mvLogDB, $mvLogTable, $row = array()) {
		$valList .= "(1, @fv_uow_id, $this->serverId," . implode(",", $row) . ")";
		$sql = sprintf("INSERT INTO %s.`%s` VALUES %s", $mvLogDB, $mvLogTable, $valList );
		mysql_query($sql, $this->dest) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_error());
	}
	

	
	function statement($sql) {

		$sql = trim($sql);
		preg_match("/^[/*!0-9-]*([A-Za-z])+\s*(.*)$/", $sql, $matches);
		
		$command = $matches[1];
		$args = $matches[2];
		
		switch($command) {
			#register change in delimiter so that we properly capture statements
			case 'DELIMITER':
				$this->delimiter = trim($args);
				break;
				
			#ignore SET for now.  I don't think we need it for anything.
			case 'SET':
				break;
				
			#NEW TRANSACTION
			case 'BEGIN':
				$this->start_transaction();
				break;
			#END OF BINLOG, or binlog terminated early, or mysqlbinlog had an error
			case 'ROLLBACK':
				$this->rollback_transaction();
				break;
				
			case 'COMMIT':
				$this->commit_transaction();
				break;
				
			#Might be interestested in CREATE TABLE at some point, but not right now.
			case 'CREATE':
				/* TODO: Eventually we want to be able to auto-register tables for changelogging when they are 
				 *       created.
				 */
				break;

			#DML IS BAD....... :(
			case 'INSERT':
			case 'UPDATE':
			case 'DELETE':
			case 'REPLACE':
			case 'TRUNCATE':
				/* TODO: If the table is not being logged, ignore DML on it... */
				if($this->raiseWarnings) trigger_error('Detected statement DML on a table!  Changes can not be tracked!' , E_USER_WARNING);
				break;

			#ALTER we can deal with via some clever regex, when I get to it.  Need a test case
			#with some complex alters
			case 'ALTER':
				/* TODO: If the table is not being logged, ignore ALTER on it...  If it is being logged, modify ALTER appropriately and apply to the log.*/ 
				if($this->raiseWarnings) trigger_error('Detected ALTER on a table!  This may break CDC.  Alter the log table manually if necessary.' , E_USER_WARNING);
				break;

			#DROP probably isn't bad.  We might be left with an orphaned change log.	
			case 'DROP':
				/* TODO: If the table is not being logged, ignore DROP on it.  
				 *       If it is being logged then drop the log and maybe any materialized views that use the table.. 
				 *       Maybe throw an errro if there are materialized views that use a table which is dropped... (TBD)*/
				if($this->raiseWarnings) trigger_error('Detected DROP on a table!  This may break CDC, particularly if the table is recreated with a different structure.' , E_USER_WARNING);
				break;
				
			#I might have missed something important.  Catch it.	
			#Maybe this should be E_USER_ERROR
			default:
				if($this->raiseWarnings) trigger_error('Unknown command: ' . $command, E_USER_WARNING);
				break;
		}
	}
	
	function process_binlog($proc) {
		static $mvlogDB = false;
		$this->timeStamp = false;

		$this->refresh_mvlog_cache();
		$sql = "";

		$lastLine = "";

		#read from the mysqlbinlog process one line at a time.
		#note the $lastLine variable - we process rowchange events
		#in another procedure which also reads from $proc, and we
		#can't seek backwards, so this function returns the next line to process
		#In this case we use that line instead of reading from the file again
		while( !feof($proc) ) {
			if($lastLine) {
				#use a previously saved line (from process_rowlog)
				$line = $lastLine;
				$lastLine = "";
			} else {
				#read from the process
				$line = trim(fgets($proc));
			}

			#echo "-- $line\n";
			#It is faster to check substr of the line than to run regex
			#on each line.
			$prefix=substr($line, 0, 5);
			$matches = array();

			#Control information from MySQLbinlog is prefixed with a hash comment.
			if($prefix[0] == "#") {
				$binlogStatement = "";
				if (preg_match('/^#([0-9: ]+).*\s+end_log_pos ([0-9]+)\s+([^ ]+)/', $line,$matches)) {
					$this->timeStamp = $matches[1];
					$this->binlogPosition = $matches[2];
					$this->binlogServerId = $matches[3];
				} else {
					#decoded RBR changes are prefixed with ###				
					if($prefix == "### I" || $prefix == "### U" || $prefix == "### D") {
						if(preg_match('/### (UPDATE|INSERT INTO|DELETE FROM)\s([^.]+)\.(.*$)/', $line, $matches)) {
							$this->db          = $matches[2];
							$this->base_table  = $matches[3];
						
							if($this->db == 'flexviews' && $this->base_table == 'mvlogs') {
								refresh_mvlog_cache();
							}
		
							if(!empty($this->mvlogList[$this->db . $this->base_table])) {
								$this->mvlog_table = $this->mvlogList[$this->db . $this->base_table];
								$lastLine = process_rowlog($proc);
								continue;
							}
						}
					} 
				}
		 
			}	else {
				
				if($binlogStatement) {
					$binlogStatement .= " ";
				}
				$binlogStatement .= $line;
				if(substr($line,-1 * strlen($this->delimiter) == $this->delimiter)) {
					#this is a statement
					$this->statement($binlogStatement);
					$binlogStatement = "";
				} 
			}
		}
	}
	
	function process_rowlog($proc) {
		$sql = "";
		$line = "";
		$skip_rows = false;

		#if there is a list of databases, and this database is not on the list
		#then skip the rows
		if(!empty($this->onlyDatabases) && empty($this->onlyDatabases[trim($this->db)])) {
			$skip_rows = true;
		}

		# loop over the input, collecting all the input values into a set of INSERT statements
		$row = array();
		$mode = 0;
		
		while($line = fgets($proc)) {
			#echo "***$line";
			$line = trim($line);
			
            #DELETE and UPDATE statements contain a WHERE clause with the OLD row image
			if($line == "### WHERE") {
				$mode = -1;
				
			#INSERT and UPDATE statements contain a SET clause with the NEW row image
			} elseif($line == "### SET")  {
				$mode = 1;
			
			#Row images are in format @1 = 'abc'
			#                         @2 = 'def'
			#Where @1, @2 are the column number in the table	
			} elseif(preg_match('/###\s+@[0-9]+=(.*)$/', $line, $matches)) {
				$row[] = $val;

			#This line does not start with ### so we are at the end of the images	
			} else {
				if(!$skip_rows) {
					switch($mode) {
						case -1:
							$this->delete_row($mvLogDB, $table, $row);
							break;
						case 1:
							$this->insert_row($mvLogDB, $table, $row);
							break;
						default:
							die('UNEXPECTED MODE IN PROCESS_ROWLOG!');
					}					
				} 
				$row = array();
				break; #out of while
			}
			#keep reading lines
		}
		#return the last line so that we can process it in the parent body
		#you can't seek backwards in a proc stream...
		return $line;
	}

}


