#!/usr/local/bin/php
<?php
error_reporting(E_ALL);

class FlexCDC {
	static function concat() {
    	$result = "";
    	for ($i = 0;$i < func_num_args();$i++) {
      		$result .= func_get_arg($i) . " ";
    	}
    	return $result;
  	}
	private $mvlogDB = NULL;
	private	$mvlogList = array();
	
	private $onlyDatabases = array();
	private $cmdLine;

	private $source = NULL;
	private $dest = NULL;

	private $serverId = NULL;
	
	private $binlogServerId;
	
	public  $raiseWarnings = true;
	
	public  $delimiter = ';';
	public function get_source() {
		return $this->source;
	}
	public function get_dest() {
		return $this->dest;
	}
	#Construct a new consumer object.
	#By default read settings from the INI file unless they are passed
	#into the constructor	
	public function __construct($settings = NULL) {
		
		if(!$settings) {
			$settings = $this->read_settings();
		}
		if(!$this->cmdLine) $this->cmdLine = `which mysqlbinlog`;
		
		#only record changelogs from certain databases?
		if(!empty($settings['flexcdc']['only_database'])) {
			$vals = explode(',', $settings['flexcdc']['only_databases']);
			foreach($vals as $val) {
				$this->onlyDatabases[] = trim($val);
			}
		}
		
		#the mysqlbinlog command line location may be set in the settings
		#we will autodetect the location if it is not specified explicitly
		if(!empty($settings['flexcdc']['mysqlbinlog'])) {
			$this->cmdLine = $settings['flexcdc']['mysqlbinlog'];
		} 
		
		#build the command line from user, host, password, socket options in the ini file in the [source] section
		foreach($settings['source'] as $k => $v) {
			$this->cmdLine .= " --$k=$v";
		}
		
		#database into which to write mvlogs
		$this->mvlogDB = $settings['flexcdc']['database'];
		
		#shortcuts
		$S = $settings['source'];
		$D = $settings['dest'];
	
		/*TODO: support unix domain sockets */
		$this->source = mysql_connect($S['host'] . ':' . $S['port'], $S['user'], $S['password'], true) or die('Could not connect to MySQL server:' . mysql_error());
		$this->dest = mysql_connect($D['host'] . ':' . $D['port'], $D['user'], $D['password'], true) or die('Could not connect to MySQL server:' . mysql_error());
	    
	}
	
	#Capture changes from the source into the dest
	public function capture_changes($setup_schema=true) {
				
		$first_run = $this->initialize_dest();
		$this->get_source_logs();
		$this->cleanup_logs();

		if($first_run && $setup_schema) {
			#find the current master position
			$stmt = mysql_query('FLUSH TABLES WITH READ LOCK', $this->source) or die(mysql_error($this->source));
			$stmt = mysql_query('SHOW MASTER STATUS', $this->source) or die(mysql_error($this->source));
			$row = mysql_fetch_assoc($stmt);
			$stmt = mysql_query('UNLOCK TABLES', $this->source) or die(mysql_error($this->source));
			
			mysql_query("BEGIN;", $this->dest);
			
			$sql = "UPDATE binlog_consumer_status bcs 
			           set exec_master_log_pos = master_log_size 
			         where server_id={$this->serverId} 
			           AND master_log_file < '{$row['File']}'";
			$stmt = mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error($this->dest) . "\n");

			$sql = "UPDATE binlog_consumer_status bcs 
			           set exec_master_log_pos = {$row['Position']} 
			         where server_id={$this->serverId} 
			           AND master_log_file = '{$row['File']}'";
			$stmt = mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error($this->dest) . "\n");
			
			mysql_query("commit;", $this->dest);
			
		}
		
		#retrieve the list of logs which have not been fully processed
		#there won't be any logs if we just initialized the consumer above
		$sql = "SELECT bcs.* 
		          FROM `" . $this->mvlogDB . "`.`binlog_consumer_status` bcs 
		         WHERE server_id=" . $this->serverId .  
		       "   AND exec_master_log_pos < master_log_size 
		         ORDER BY master_log_file;";
		
	
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
	
		$settings=@parse_ini_file($iniFile,true) or die("Could not read ini file: $iniFile\n");
		if(!$settings || empty($settings->settings['flexcdc'])) {
			die("Could not find [flexcdc] section or .ini file not found");
		}

	}

	
	private function refresh_mvlog_cache() {
		
		$this->mvlogList = array();
			
		$sql = "SELECT table_schema, table_name, mvlog_name from mvlogs where active_flag=1";
		$stmt = mysql_query($sql, $this->dest);
		while($row = mysql_fetch_array($stmt)) {
			$this->mvlogList[$row[0] . $row[1]] = $row[3];
		}
	}
	
	/* Set up the destination connection */
	function initialize_dest() {
		$return = 0;
		if(!mysql_select_db($this->mvlogDB,$this->dest)) {
			 mysql_query('CREATE DATABASE ' . $this->mvlogDB) or die('Could not CREATE DATABASE ' . $this->mvlogDB . "\n");
			 
		}
		
		mysql_query("CREATE TABLE 
		             IF NOT EXISTS 
					 mvlogs (table_schema varchar(50), 
                             table_name varchar(50), 
                             mvlog_name varchar(50),
                             active_flag boolean default true
                     ) ENGINE=INNODB DEFAULT CHARSET=utf8;"
		            , $this->dest) or die('COULD NOT CREATE TABLE mvlogs: ' . mysql_error($this->dest) . "\n");; 


		mysql_query("CREATE TABLE 
		             IF NOT EXISTS
					 `binlog_consumer_status` (
  					 	`server_id` int not null, 
  						`master_log_file` varchar(100) NOT NULL DEFAULT '',
  						`master_log_size` int(11) DEFAULT NULL,
  						`exec_master_log_pos` int(11) default null,
  						PRIMARY KEY (`server_id`, `master_log_file`)
					  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
		            , $this->dest) or die('COULD NOT CREATE TABLE binlog_consumer_status: ' . mysql_error($this->dest) . "\n");
		
		#return 1 if the table already existed
		$stmt = mysql_query('SHOW WARNINGS', $this->dest) or die(mysql_error());
		$row = mysql_fetch_assoc($stmt);
		if($row) $return = 1;
		
		mysql_query("BEGIN;", $this->dest) or die(mysql_error());
		mysql_query("CREATE TEMPORARY table log_list (log_name char(50), primary key(log_name))",$this->dest) or die(mysql_error());
		$stmt = mysql_query("SET SQL_LOG_BIN=0", $this->dest);
		if(!$stmt) die(mysql_error());
		
		return $return;
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
			$sql = sprintf("INSERT INTO binlog_consumer_status (server_id, master_log_file, master_log_size, exec_master_log_pos) values (%d, '%s', %d, 0) ON DUPLICATE KEY UPDATE master_log_size = %d ;", $this->serverId,$row['Log_name'], $row['File_size'], $row['File_size']);
			mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");
	
			$sql = sprintf("INSERT INTO log_list (log_name) values ('%s')", $row['Log_name']);
			mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");
		}
	}
	
	/* Remove any logs that have gone away */
	function cleanup_logs() {
		
		// TODO Detect if this is going to purge unconsumed logs as this means we either fell behind log cleanup, the master was reset or something else VERY BAD happened!
		$sql = "DELETE bcs.* FROM binlog_consumer_status bcs where server_id={$this->serverId} AND master_log_file not in (select log_name from log_list)";
		mysql_query($sql, $this->dest) or die($sql . "\n" . mysql_error() . "\n");

		$sql = "DROP TEMPORARY table log_list";
		mysql_query($sql, $this->dest) or die("Could not drop TEMPORARY TABLE log_list\n");
		
	}

	/* Update the binlog_consumer_status table to indicate where we have executed to. */
	function set_capture_pos() {
		
		$sql = sprintf("UPDATE binlog_consumer_status set exec_master_log_pos = %d where master_log_file = '%s' and server_id = %d",$this->serverId, $this->binlogPosition, $this->logName);
		mysql_query($sql, $this->dest) or die("COULD NOT EXEC:\n$sql\n" . mysql_error($this->dest));
		
	}

	/* Called when a new transaction starts*/
	function start_transaction() {
		
		mysql_query("START TRANSACTION", $this->dest) or die("COULD NOT START TRANSACTION;\n" . mysql_error());
        $this->set_capture_pos();
		$sql = sprintf("INSERT INTO mview_uow values(NULL,str_to_date('%s', '%%y%%m%%d %%H:%%i:%%s'));",rtrim($this->timeStamp));
		mysql_query($sql,$this->dest) or die("COULD NOT CREATE NEW UNIT OF WORK:\n$sql\n" .  mysql_error());
		 
		$sql = "SET @fv_uow_id := LAST_INSERT_ID();";
		mysql_query($sql, $this->dest) or die("COULD NOT EXEC:\n$sql\n" . mysql_error($this->dest));

	}

    
    /* Called when a transaction commits */
	function commit_transaction() {
		
		$this->set_capture_pos();
		mysql_query("COMMIT", $this->dest) or die("COULD NOT COMMIT TRANSACTION;\n" . mysql_error());
	}

	/* Called when a transaction rolls back */
	function rollback_transaction() {
		
		mysql_query("ROLLBACK", $this->dest) or die("COULD NOT ROLLBACK TRANSACTION;\n" . mysql_error());
		#update the capture position and commit, because we don't want to keep reading a truncated log
		$this->set_capture_pos();
		mysql_query("COMMIT", $this->dest) or die("COULD NOT COMMIT TRANSACTION LOG POSITION UPDATE;\n" . mysql_error());
		
	}

	/* Called when a row is deleted, or for the old image of an UPDATE */
	function delete_row($mvLogDB, $mvLogTable, $row = array()) {
		$valList .= "(1, @fv_uow_id, {$this->binlogServerId}," . implode(",", $row) . ")";
		$sql = sprintf("INSERT INTO `%s`.`%s` VALUES %s", $mvLogDB, $mvLogTable, $valList );
		mysql_query($sql, $dest) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_error());
	}

	/* Called when a row is inserted, or for the new image of an UPDATE */
	function insert_row($mvLogDB, $mvLogTable, $row = array()) {
		$valList .= "(1, @fv_uow_id, $this->binlogServerId," . implode(",", $row) . ")";
		$sql = sprintf("INSERT INTO `%s`.`%s` VALUES %s", $mvLogDB, $mvLogTable, $valList );
		mysql_query($sql, $this->dest) or die("COULD NOT EXEC SQL:\n$sql\n" . mysql_error());
	}
	/* Called for statements in the binlog.  It is possible that this can be called more than
	 * one time per event.  If there is a SET INSERT_ID, SET TIMESTAMP, etc
	 */	
	function statement($sql) {
		$sql = trim($sql);
		echo "STATEMENT: $sql\n";
		#TODO: Not sure  if this might be important..
		#      In general, I think we need to worry about character
		#      set way more than we do (which is not at all)
		if(substr($sql,0,6) == '/*!\C ') {
			return;
		}
		
		if($sql[0] == '/') {
			$end_comment = strpos($sql, ' ');
			$sql = trim(substr($sql, $end_comment, strlen($sql) - $end_comment));
		}
		
		preg_match("/([^ ]+)(.*)/", $sql, $matches);
		
		//print_r($matches);
		
		$command = $matches[1];
		$command = str_replace($this->delimiter,'', $command);
		$args = $matches[2];
		
		switch(strtoupper($command)) {
			#register change in delimiter so that we properly capture statements
			case 'DELIMITER':
				$this->delimiter = trim($args);
				break;
				
			#ignore SET and USE for now.  I don't think we need it for anything.
			case 'SET':
			case 'USE':	
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
		$binlogStatement="";
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
						
							if($this->db == $this->mvlogDB && $this->base_table == 'mvlogs') {
								$this->refresh_mvlog_cache();
							}
		
							if(empty($this->mvlogList[$this->db . $this->base_table])) {
								if($this-auto_changelog) {
								 	$this->create_mvlog($this->db, $this->base_table);  
								 	$this->refresh_mvlog_cache();
								}
							}
							$this->mvlog_table = $this->mvlogList[$this->db . $this->base_table];
							$lastLine = process_rowlog($proc);
							
						}
					} 
				}
		 
			}	else {
				
				if($binlogStatement) {
					$binlogStatement .= " ";
				}
				$binlogStatement .= $line;
				
				if(strpos($binlogStatement, $this->delimiter, strlen($binlogStatement)-strlen($this->delimiter)-1) !== false)  {
					#process statement
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

	#AUTOPORTED FROM FLEXVIEWS.CREATE_MVLOG() w/ minor modifications for PHP
	function create_mvlog($v_schema_name,$v_table_name) { 
		$v_done=FALSE;
		$v_column_name=NULL;
		$v_data_type=NULL;
		$v_sql=NULL;
	
		$cursor_sql = "SELECT COLUMN_NAME, IF(COLUMN_TYPE='TIMESTAMP', 'DATETIME', COLUMN_TYPE) COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='$v_table_name' AND TABLE_SCHEMA = '$v_schema_name'";
	
		$cur_columns = mysql_query($cursor_sql, $this->dest);
		$v_sql = '';
	
		while(1) {
			if( $v_sql != '' ) {
				$v_sql = FlexCDC::concat($v_sql, ', ');
			}
	
			$row = mysql_fetch_array($cur_columns);
			if( $row === false ) $v_done = true;
	
			if( $row ) {
				$v_column_name = $row[0];
				$v_data_type = $row[1];
			}
	
			if( $v_done ) {
				mysql_free_result($cur_columns);
				break;
			}
	
			$v_sql = FlexCDC::concat($v_sql, $v_column_name, ' ', $v_data_type);
		}
	
		if( trim( $v_sql ) == "" ) {
			trigger_error('Could not access table:' . $v_table_name, E_USER_ERROR);
		}
			
		$v_sql = FlexCDC::concat('CREATE TABLE `', $this->mvlogDB ,'`.`' ,$v_schema_name, '_', $v_table_name,'` ( dml_type INT DEFAULT 0, uow_id BIGINT, `fv$server_id` INT UNSIGNED, ', $v_sql, 'KEY(uow_id, dml_type) ) ENGINE=INNODB');
		$create_stmt = mysql_query($v_sql, $this->dest);
		if(!$create_stmt) die('COULD NOT CREATE MVLOG. ' . $v_sql . "\n");
		$exec_sql = " INSERT INTO mvlogs( table_schema , table_name , mvlog_name ) values('$v_schema_name', '$v_table_name', '" . $v_schema_name . "_" . $v_table_name . "')";
		mysql_query($exec_sql) or die($exec_sql . ':' . mysql_error($this->dest) . "\n");
	
	}
}


