<?php

class binlog_event_consumer {
	private $table_map = array();
	private $read_pos = 0;
	
	private $event_types = array(
		'START_EVENT_V3'           => 1,
		'FORMAT_DESCRIPTION_EVENT' => 15,
		'TABLE_MAP_EVENT'          => 19,
		'WRITE_ROWS_EVENT'         => 23,
		'UPDATE_ROWS_EVENT'        => 24,
		'DELETE_ROWS_EVENT'        => 25
	);

	private $data_types = array( 
	    'decimal'         => 0,
	    'tiny'            => 1,
	    'short'           => 2,
	    'long'            => 3,
	    'float'           => 4,
	    'double'          => 5,
	    'null'            => 6,
	    'timestamp'       => 7,
	    'longlong'        => 8,
	    'int24'           => 9,
	    'date'            => 10,
	    'time'            => 11,
	    'datetime'        => 12,
	    'year'            => 13,
	    'newdate'         => 14,
	    'varchar'         => 15,
	    'bit'             => 16,
	    'newdecimal'      => 246,
	    'enum'            => 247,
	    'set'             => 248,
	    'tiny_blob'       => 249,
	    'medium_blob'     => 250,
	    'long_blob'       => 251,
	    'blob'            => 252,
	    'var_string'      => 253,
	    'string'          => 254,
	    'geometry'        => 255
	);
	private $data_type_map;
	private $event_type_map;
	private $rows = array();

	private function set($key, $val) {
		$this->$key = $val;
	}

	function __CONSTRUCT($data="") {
		$this->data_type_map = array_flip($this->data_types);
		$this->event_type_map = array_flip($this->event_types);
		$this->consume($data);
	}
	
	function consume($data) {
		if(!$data) return;
		$events = explode("\n", $data);
		$save_data = "";
		foreach($events as $event) {
			if($save_data) {
				$event = $save_data . $event;
				$save_data = "";
			}
			if(!$event) continue;
			if(substr($event, -2) != "==") {
				$save_data = $event;
				continue;
			}
			echo "DATA: $event\n";
			if(!$this->data = base64_decode($event,true)) die('base64 decode failed for: ' . $event . "\n");
			while($this->next_event());
		}
	}
	
	protected function next_event() {
		if($this->data === false || $this->data === "") return false;
		$this->read_pos = 0;
		$this->parse_event_header();
		$this->parse_event_body();

		if($this->read_pos < $this->header->event_length) {
			echo "AFTER EVENT PARSE REMAINING_DATA_LENGTH: " . strlen($this->data) . "\n";
			echo "EVENT UNDERREAD AT ACTUAL_READ_POS: {$this->read_pos} EXPECTED_READ_POS: {$this->header->event_length}\n";
		foreach(str_split($this->data) as $key => $char) {
			echo "$key => " . ord($char);
			echo "\n";
		}

		#print_r($this);
			
			exit;
		}
		if($this->read_pos > $this->header->event_length) {
			echo "AFTER EVENT PARSE REMAINING_DATA_LENGTH: " . strlen($this->data) . "\n";
			echo "EVENT OVERREAD AT ACTUAL_READ_POS: {$this->read_pos} EXPECTED_READ_POS: {$this->header->event_length}\n";
			exit;
		}
		return true;
	}
	
	function reset() {
		$this->table_map = array();
		$this->rows = array();
	}

	protected function parse_event_body() {
		switch($this->header->event_type) {
			case $this->event_types['START_EVENT_V3']:
				echo "START_EVENT_V3\n";
				break;
			case $this->event_types['TABLE_MAP_EVENT']:
				echo "TABLE_MAP_EVENT\n";
				$this->parse_table_map_event();
				break;
			case $this->event_types['WRITE_ROWS_EVENT']:
				echo "WRITE_ROWS_EVENT\n";
				$this->parse_row_event('insert');
				break;
			case $this->event_types['UPDATE_ROWS_EVENT']:
				echo "UPDATE_ROWS_EVENT\n";
				$this->parse_row_event('update');
				break;
			case $this->event_types['DELETE_ROWS_EVENT']:
				echo "UPDATE_ROWS_EVENT\n";
				$this->parse_row_event('delete');
				break;
			case $this->event_types['FORMAT_DESCRIPTION_EVENT']:
				echo "FORMAT_DESCRIPTION_EVENT\n";
				$this->parse_format_description_event();
				break;
			default:
				print_r($this->header);
				die("UNKOWN EVENT TYPE!\n");
		}
	}

	protected function parse_event_header() {
		$data = $this->read(19);
		$this->header_raw = $data;
		$this->header=(object)unpack("Vtimestamp/Cevent_type/Vserver_id/Vevent_length/Vnext_position/vflags", $data);
	}

	protected function parse_table_map_event() {
		$table_id = $this->read(6);
		#echo $this->cast($table_id) . "\n";
		$flags = $this->read(2);
		$db = $this->read_lpstringz();
		$table = $this->read_lpstringz();
		$this->table_map[$table_id] = (object)array('db'=>trim($db,chr(0)), 'table' => trim($table,chr(0)));

		$column_count = $this->cast($this->read_varint(false));
		$data = $this->read($column_count);
		$data = str_split($data);

		$columns = array();
		$length = $this->cast($this->read_varint(false)); 
		if($length) $this->table_map[$table_id]->metadata = $this->read($length);

		foreach($data as $col => $data_type) {
			$data_type = $this->cast($data_type);
			$columns[$col]['type'] = $data_type;
			// $columns[$col]['type_text'] = $this->data_types[$data_type];
			$m = $this->data_types;
			$columns[$col]['metadata'] = new StdClass(); //attach empty metadata to each column
			switch($data_type) {
				case $m['float']:
				case $m['double']:
					$columns[$col]['metadata'] = (object)array('size'=>$this->cast($this->read(1)));
				break;
				
				case $m['varchar']:
					$columns[$col]['metadata'] = (object)array('max_length' => $this->cast($this->read(2)));
				break;

				case $m['bit']:
					$bits = $this->cast($this->read(1));
					$bytes = $this->cast($this->read(1));
					$columns[$col]['metadata'] = (object)array('bits'=>(bytes * 8) + bits);
				break;
	
				case $m['newdecimal']:
					$precision = $this->cast($this->read(1));	
					$decimals = $this->cast($this->read(1));	
					$columns[$col]['metadata'] = (object)array('precision'=>$precision, 'decimals'=>$decimals);
				break;

				case $m['blob']:
				case $m['geometry']:
					$length_size = $this->cast($this->read(1));
					$columns[$col]['metadata'] = (object)array('length_size'=>$length_size);
				break;

				case $m['string']:
				case $m['var_string']:
					$real_type = $m[$this->cast($this->read(1))];
					switch($real_type) {
						case 'enum':
						case 'set':
							$size = $this->cast($parser->read(1));
							$columns[$col]['metadata'] = (object)array('size' => $size);
							$columns[$col]['type'] = $real_type;
						break;

						default:
							$size = $this->cast($parser->read(1));
							$columns[$col]['metadata'] = (object)array('max_length' => $size);
					}
				break;
					
			}
		}

		$nullable = $this->read_bit_array($column_count,false);

		for($i=0;$i<count($columns);++$i) {
			$columns[$i] = (object)$columns[$i];
			$columns[$i]->nullable = $nullable[$i];
		}

		$this->table_map[$table_id]->columns = $columns;
		
	}

	protected function parse_format_description_event() {
		$this->fde = new StdClass;
		$this->fde->encoded = $this->data;
		$this->fde->binlog_version = $this->cast($this->read(2));
		$this->fde->server_version = $this->read(50);
		$this->fde->create_timestamp = $this->cast($this->read(4));
		$this->fde->header_length = $this->cast($this->read(1));
		$this->fde->footer = $this->read_to_end();
	}
	
	protected function parse_row_event($mode='insert') {
		$fields = array();
		$table_id = $this->read(6);
		if(empty($this->table_map[$table_id])) die('ROW IMAGE WITHOUT MAPPING TABLE MAP');
		$flags = $this->read(2);
		$column_count = $this->cast($this->read_varint(false));
		$columns_used=array();
		switch($mode) {
			case 'insert':
					echo "READING USED FOR NEW\n";
					$columns_used = $this->read_bit_array($column_count, false);
					while($this->data){
						++$this->gsn;
						$data=$this->read_row_image($table_id, $columns_used);
						$this->rows[$table_id] = array('dml_mode' => 1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used, 'image'=>$data['image'], 'nulls' => $data['nulls']);
					}
			break;
			
			case 'update':
					echo "READING USED FOR OLD\n";
					$columns_used['old'] = $this->read_bit_array($column_count,false);
					echo "READING USED FOR NEW\n";
					$columns_used['new'] = $this->read_bit_array($column_count,false);
					while($this->data) {	
						++$this->gsn;
						$data = $this->read_row_image($table_id, $columns_used['old']);
						$this->rows[$table_id] = array('dml_mode' => -1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used['old'], 'image'=>$data['image'], 'nulls' => $data['nulls']);
				
						++$this->gsn;
						$data = $this->read_row_image($table_id, $columns_used['new']);
						$this->rows[$table_id] = array('dml_mode' => 1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used['new'], 'image'=>$data['image'], 'nulls' => $data['nulls']);
					}
				
			break;
			
			case 'delete':
					echo "READING USED FOR OLD\n";
					++$this->gsn;
					$columns_used = $this->read_bit_array($column_count, false);
					while($this->data) {
						$data = $this->read_row_image($table_id, $columns_used);
						$this->rows[$table_id] = array('dml_mode' => -1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used, 'image'=>$data['image'], 'nulls' => $data['nulls']);
					}
				
			break;	
		}
		
	}
	
	protected function read_row_image($table_id, $columns_used) {
		echo "READING ROW IMAGE\n";
		$row_data = "";
		echo "Reading NULL column bit array\n";
		$columns_null = $this->read_bit_array(count($this->table_map[$table_id]->columns), false);
		echo "USED:\n";
		print_r($columns_used);
		echo "NULL:\n";
		print_r($columns_null);

		foreach($this->table_map[$table_id]->columns as $col => $col_info)	{
			if(!$columns_used[$col]) {
				continue;
			} elseif ($columns_null[$col]) {
				continue;
			}
			$row_data .= $this->read_mysql_type($col_info);
		}
		return array('nulls' => $columns_null, 'image' => $row_data);
	}
	
	protected function cast($data, $bits=false) {
		if ($bits === false) $bits = strlen($data) * 8;
		if($bits <= 0 ) return false;
		switch($bits) {
			case 8:
				$return = unpack('C',$data);
				$return = $return[1];
			break;

			case 16:
				$return = unpack('v',$data);
				$return = $return[1];
			break;

			case 24:
				$return = unpack('ca/ab/cc', $data);
				$return = $return['a'] + ($return['b'] << 8) + ($return['c'] << 16);
			break;

			case 32:
				$return = unpack('V', $data);
				$return = $return[1];
			break;

			case 48:
				$return = unpack('va/vb/vc', $data);
				$return = $return['a'] + ($return['b'] << 16) + ($return['c'] << 32);
			break;

			case 64:
				$return = unpack('Va/Vb', $data);
				$return = $return['a'] + ($return['b'] << 32);
			break;

		}
		return $return;
	}

	protected function read($bytes,$message="") {
		$return = substr($this->data,0,$bytes);
		if ($message) echo "$message READ: $bytes, GOT: " . strlen($return) . "\n";
		$this->read_pos += $bytes;
		$this->data = substr($this->data, $bytes);
		return $return;
	}

	protected function read_varint($keep_packed=true) {
		$data = $this->read(1);
      		$first_byte = $this->cast($data,8);
		if($first_byte <= 250) return $data;
		if($first_byte == 251) return null;
		if($first_byte == 252) return ($keep_packed ? $data : '') . $this->read(2);
		if($first_byte == 253) return ($keep_packed ? $data : '') . $this->read(3);
		if($first_byte == 254) return ($keep_packed ? $data : '') . $this->read(8);
		if($first_byte == 255) die('invalid varint length found!\n');
	}

	protected function read_lpstring($size=1, $with_null = false) {
		$length = $this->cast($this->read($size));
		return $this->read($length + $with_null);
	}

	protected function read_to_end() {
		$return = $this->data;
		$this->read_pos += strlen($return);
		#echo "READ_TO_END: " . strlen($return) . "\n";
		$this->data="";
		return $return;
	}

	protected function read_lpstringz($size=1) {
		return $this->read_lpstring($size, true);
	}

	protected function read_nullstring($keep_null = true) {
		$return = "";
		while(1) {
			$char = $this->read(1);
			if($char === chr(0)) break;
			$return .= $char;
			if($this->data === "") die("did not find end of string!\n");
		}
		if($keep_null) $return .= $char;
		return $return;
	}

	protected function read_varstring() {
		$data = $this->read_varint;
		$length = $this->cast($data, strlen($data) * 8);
		return $data . $this->read($length);
	}

	protected function read_bit_array($size=1, $keep_packed=true) {
		$data = $this->read(floor(($size+7)/8),'reading bit array');
		if($keep_packed) return $data;
		$output = "";	
		$l = strlen($data);
		for($i = 0; $i < $l; ++$i) {
			$output .= str_pad(decbin(ord(substr($data,$i,1))),8,'0',STR_PAD_LEFT);
		}
		return str_split(strrev($output));
	}

	protected function read_newdecimal($i, $f) {
		$i_bytes = floor($i / 9) * 4;
		$i_bytes += $this->leftover_to_bytes($i % 9);
		$f_bytes = floor($f / 9) * 4;
		$f_bytes += $this->leftover_to_bytes($f % 9);
		return($this->read($i_bytes + $f_bytes));
	}

	protected function leftover_to_bytes($digits) {
		if($digits === 0) return 0;
		if($digits <= 2) return 1;
		if($digits <= 4) return 2;
		if($digits <= 6) return 3;
		if($digits <= 9) return 4;
	}

	protected function read_mysql_type($col_info) {
		$data_type = $col_info->type;
		$metadata = $col_info->metadata;
		$m = &$this->data_types;
		echo "READ_MYSQL_TYPE: " . $this->data_type_map[$data_type] . "\n";

		switch($data_type) {
			case $m['tiny']:
			return $this->read(1);
			case $m['short']:
			return $this->read(2);
			case $m['int24']:
			return $this->read(3);
			case $m['long']:
			$d = $this->read(4);
			ECHO "LONG: " . $this->cast($d) . "\n";
			return $d;

			case $m['longlong']:
			return $this->read(8);
			case $m['float']:
			return $this->read(4);
			case $m['double'];
			return $this->read(8);
			case $m['string']: 
			case $m['var_string']:
			return $this->read_varstring();
			case $m['varchar']:
			return $this->read_lpstring(2);
			case $m['blob']: 
			case $m['geometry']:
			return $this->read_lpstring($metadata->length_size);
			case $m['timestamp']: 
			return $this->read(4);	
			case $m['year']:
			return $this->read(1);
			case $m['date']:
			case $m['time']:
			return $this->read(3);
			case $m['datetime'];
			return $this->read(8);
			case $m['enum']: 
			case $m['set']:
			return $this->read($metadata->size * 8);
			case $m['bit']:
			return $this->read_bit_array($metadata->bits);
			case $m['newdecimal']:
			return $this->read_newdecimal($metadata->precision, $metadata->decimals);
			default: die("DO NOT KNOW HOW TO READ TYPE: $data_type\n");
		}

		return false;
	}
			
}



$b = '
nnr0Tw8CAAAAZwAAAGsAAAABAAQANS41LjI0LXJlbDI2LjAtbG9nAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAACeevRPEzgNAAgAEgAEBAQEEgAAVAAEGggAAAAICAgCAA==
';

$consumer = new binlog_event_consumer($b);
$b = '
uXr0TxMCAAAAOwAAAPAAAAAAAIgAAAAAAAEACmdlb2dyYXBoaWMACXRlc3RfY2FzZQAC9vYECgoU
CgM=
uXr0TxcCAAAALQAAAB0BAAAAAIgAAAAAAAEAAv/8SA5gD/+EEZTYAAAPQkAA
';
$consumer->consume($b);
//print_r($event);

$b ='
e/X1TxMCAAAAPAAAAEsHAAAAAJkAAAAAAAEACmdlb2dyYXBoaWMACXRlc3RfY2FzZQAD9vYDBAoK
FAoD
e/X1TxgCAAAAbgAAALkHAAAAAJkAAAAAAAEAA///+EgOYA//hBGU2AAAD0JAAAMAAAD4SA5gD/+E
EZTYAAAPQkAABQAAAPhIDmAP/4QRlNgAAA9CQAAEAAAA+EgOYA//hBGU2AAAD0JAAAYAAAA=
';
$consumer->consume($b);


$b=
'
RLH3TxMCAAAANAAAAN8AAAAAAJwAAAAAAAEACmdlb2dyYXBoaWMABXRlc3QyAAMDAwMABw==
RLH3TxcCAAAAKgAAAAkBAAAAAJwAAAAAAAEAA//4AQAAAAIAAAADAAAA
';
$consumer->consume($b);
#$consumer->reset();

$b = '
qRT6TxMCAAAANAAAAN8AAAAAACEAAAAAAAEACmdlb2dyYXBoaWMABXRlc3QyAAMDAwMABw==
qRT6TxcCAAAANwAAABYBAAAAACEAAAAAAAEAA//4BgAAAAYAAAAGAAAA+AcAAAAHAAAABwAAAA==
';
$consumer->consume($b);

$b = '
Dg36TxMCAAAANAAAAN8AAAAAACEAAAAAAAEACmdlb2dyYXBoaWMABXRlc3QyAAMDAwMABw==
Dg36TxgCAAAAUgAAADEBAAAAACEAAAAAAAEAA///+AEAAAACAAAAAwAAAPgBAAAAAgAAAAQAAAD4
AQAAAAIAAAADAAAA+AEAAAACAAAABAAAAA==
';

$consumer->consume($b);


#print_r($consumer);


