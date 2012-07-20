<?php

class binlog_event_consumer {
	public $table_map = array();
	public $rows = array();
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

	public $gsn;

	public function set($key, $val) {
		$this->$key = $val;
	}

	public function get($key) {
		return $this->$key;
	}

	function __CONSTRUCT($data="", $gsn) {
		$this->gsn = $gsn;
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
			if(strlen($event) === 76 && substr($event, -1) !== '=') {
				$save_data = $event;
				continue;
			}

			$this->raw_data = $event;
			echo "RAW EVENT: $event\n";
			echo "RAW LEN:" . strlen($event) . "\n";
			while($this->next_event());
		}
	}
	
	protected function next_event() {
		if($this->raw_data === false || $this->raw_data === "") return false;
		$header = substr($this->raw_data,0,28); # 28 = (19 * 4 / 3) + 3
		echo "HEADER: $header LEN: " . strlen($header) . "\n";
		if(!$this->data .= base64_decode($header,true)) die('base64 decode failed for: ' . $header . "\n");
		echo "DECODED LEN: " . strlen($this->data) . "\n";

		$this->read_pos = 0;
		$this->parse_event_header();

		$body_size = $this->header->event_length - 19;
		$bytes_to_decode = floor($body_size * 4 / 3) + ( ($body_size * 4 % 3) != 0 ? 4 - ($body_size * 4 % 3) : 0 );
		$body = substr($this->raw_data, 28, $bytes_to_decode);

		echo "EXPECT BODY SIZE(after decoding): $body_size, BODY SIZE(encoded): $bytes_to_decode, BYTES IN STREAM: " . strlen($body) . "\n";
		if(!$this->data .= base64_decode($body,true)) die('base64 decode failed for: ' . $body . "\n");
		$this->raw_data = substr($this->raw_data, $bytes_to_decode + 28);

		echo "EXPECTED BODY SIZE: $body_size, GOT BODY SIZE: " . strlen($this->data) . "\n";
		$this->parse_event_body();
		echo "AT ACTUAL_READ_POS: {$this->read_pos} EXPECTED_READ_POS: {$this->header->event_length}\n";

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
		$this->data = "";
		$this->raw_data = "";
		$this->read_pos = 0;
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
		$this->table_map[$table_id] = new StdClass;
		echo "TABLE_ID(decoded): " . $this->cast($table_id) . "\n";
		$this->table_map[$table_id]->raw_flags = $this->read(2);
		$db = $this->read_lpstringz();
		$table = $this->read_lpstringz();
		echo "DB: $db TABLE: $table [note: null trimmed on storage]\n";
		$this->table_map[$table_id]->db    = trim($db,chr(0));
		$this->table_map[$table_id]->table = trim($table,chr(0));
		
		$column_count = $this->cast($this->read_varint(false));
		echo "COLUMN COUNT: $column_count\n";
		$data = $this->read($column_count);
		$this->table_map[$table_id]->raw_column_data = $data;
		$data = str_split($data);

		$columns = array();
		$length = $this->cast($this->read_varint(false)); 
		echo "EXTRA LENGTH: $length\n";

		$this->table_map[$table_id]->raw_metadata = "";
		foreach($data as $col => $data_type) {
			echo "GETTING METADATA FOR @$col OF DATA TYPE: ". $this->data_type_map[$this->cast($data_type)] . "\n";
			$data_type = $this->cast($data_type);
			$columns[$col]['type'] = $data_type;
			// $columns[$col]['type_text'] = $this->data_types[$data_type];
			$m = $this->data_types;
			$columns[$col]['metadata'] = new StdClass(); //attach empty metadata to each column
			switch($data_type) {
				case $m['float']:
				case $m['double']:
					$data = $this->read(1);
					$this->table_map[$table_id]->raw_metadata .= $data;
					$columns[$col]['metadata'] = (object)array('size'=>$this->cast($data));
				break;
			
				case $m['varchar']:
					$data = $this->read(2);
					$this->table_map[$table_id]->raw_metadata .= $data;
					$columns[$col]['metadata'] = (object)array('max_length' => $this->cast($data));
				break;
		

				case $m['bit']:
					$bits = $this->cast($this->read(1));
					$bytes = $this->cast($this->read(1));
					$this->table_map[$table_id]->raw_metadata .= $bits . $bytes;
					$columns[$col]['metadata'] = (object)array('bits'=>(bytes * 8) + bits);
				break;
	
				case $m['newdecimal']:
					$precision = $this->read(1);	
					$scale = $this->read(1);	
					$this->table_map[$table_id]->raw_metadata .= $precision. $scale;
					$precision = $this->cast($precision);
					$scale = $this->cast($scale);	
					$columns[$col]['metadata'] = (object)array('precision'=>$precision, 'scale'=>$scale);
				break;

				case $m['blob']:
				case $m['geometry']:
					$length_size = $this->cast($this->read(1));
					$this->table_map[$table_id]->raw_metadata .= $length_size;
					$columns[$col]['metadata'] = (object)array('length_size'=>$length_size);
				break;

				case $m['string']:
				case $m['var_string']:
					$real_type = $m[$this->cast($this->read(1))];
					$this->table_map[$table_id]->raw_metadata .= $real_type;
					switch($real_type) {
						case 'enum':
						case 'set':
							$data = $parser->read(1);
							$size = $this->cast($data);
							$this->table_map[$table_id]->raw_metadata .= $data;
							$columns[$col]['metadata'] = (object)array('size' => $size);
							$columns[$col]['type'] = $real_type;
						break;

						default:
							
							$data = $parser->read(1);
							$this->table_map[$table_id]->raw_metadata .= $data;
							$size = $this->cast($data);
							$columns[$col]['metadata'] = (object)array('max_length' => $size);
					}
				break;
			}	
		}
		echo "SAVED METADATA LEN: " . strlen($this->table_map[$table_id]->raw_metadata) . "\n";
		
		$this->table_map[$table_id]->raw_nullable = $this->read_bit_array($column_count,true);
		$nullable = $this->unpack_bit_array($this->table_map[$table_id]->raw_nullable);

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
		echo "PARSING ROW EVENT\n";
		$fields = array();
		$table_id = $this->read(6);
		if(empty($this->table_map[$table_id])) die('ROW IMAGE WITHOUT MAPPING TABLE MAP');
		$flags = $this->read(2);
		$column_count = $this->cast($this->read_varint(false));
		$columns_used=array();
		if(empty($this->rows[$table_id])) $this->rows[$table_id] = array();

		switch($mode) {
			case 'insert':
					echo "READING COLUMNS USED\n";
					$columns_used = $this->read_bit_array($column_count, false);
					++$this->gsn;
					while($this->data){
						echo "READING AN IMAGE\n";
						$data=$this->read_row_image($table_id, $columns_used);
						$this->rows[$table_id][] = (object)array('dml_mode' => 1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used, 'image'=>$data['image'], 'nulls' => $data['nulls']);
					}
			break;
			
			case 'update':
					$columns_used['old'] = $this->read_bit_array($column_count,false);
					$columns_used['new'] = $this->read_bit_array($column_count,false);
					while($this->data) {	
						++$this->gsn;
						$data = $this->read_row_image($table_id, $columns_used['old']);
						$this->rows[$table_id][] = (object)array('dml_mode' => -1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used['old'], 'image'=>$data['image'], 'nulls' => $data['nulls']);
				
						++$this->gsn;
						$data = $this->read_row_image($table_id, $columns_used['new']);
						$this->rows[$table_id][] = (object)array('dml_mode' => 1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used['new'], 'image'=>$data['image'], 'nulls' => $data['nulls']);
					}
				
			break;
			
			case 'delete':
					$columns_used = $this->read_bit_array($column_count, false);
					++$this->gsn;
					while($this->data) {
						$data = $this->read_row_image($table_id, $columns_used);
						$this->rows[$table_id][] = (object)array('dml_mode' => -1, 'gsn'=>$this->gsn, 'columns_used'=>$columns_used, 'image'=>$data['image'], 'nulls' => $data['nulls']);
					}
				
			break;	
		}
		
	}
	
	protected function read_row_image($table_id, $columns_used) {
		$row_data = "";

		$columns_null = $this->read_bit_array(count($this->table_map[$table_id]->columns), false);

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
		if ($message) echo "$message LEFT: " . strlen($this->data) . " REQD: $bytes, GOT: " . strlen($return) . "\n";
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
		$data = $this->read($size);
		$s = str_split($data);
		foreach($s as $i => $c) {
			echo "$i => " . ord($c) . "\n";
		}
		$length = $this->cast($data);
			
		echo "LEN READ FOR VARCHAR: $length\n";	
		$data = $this->read($length + $with_null);
		echo "READ DATA: $data\n";
		return $data;
	}

	protected function read_to_end() {
		$return = $this->data;
		$this->read_pos += strlen($return);
		echo "READ_TO_END: " . strlen($return) . "\n";
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
		$bytes = floor(($size+7)/8);
		$data = $this->read($bytes,'reading bit array');
		if($keep_packed) return $data;
		return $this->unpack_bit_array($data);
	}

	public function unpack_bit_array($data) {
		$output = "";	
		$data = str_split($data);
		foreach($data as $char) {
			$output .= str_pad(decbin(ord($char)),8,'0',STR_PAD_LEFT);
		}
		return str_split(strrev($output));
	}

	protected function read_newdecimal($precision, $scale) {
		echo "READING NEWDEC P:$precision S:$scale\n";
		$digits_per_integer = 9;
      		$compressed_bytes = array(0, 1, 1, 2, 2, 3, 3, 4, 4, 4);
      		$integral = ($precision - $scale);
      		$uncomp_integral = floor($integral / $digits_per_integer);
      		$uncomp_fractional = floor($scale / $digits_per_integer);
      		$comp_integral = $integral - ($uncomp_integral * $digits_per_integer);
      		$comp_fractional = $scale - ($uncomp_fractional * $digits_per_integer);
      		$size = $compressed_bytes[$comp_integral];
		$data = "";

		if($size > 0) {
			$data = $this->read($size);
		}

		for($i=0;$i<$uncomp_integral;++$i) {
			$data .= $this->read(4);
		}

		for($i=0;$i<$uncomp_fractional;++$i) {
			$data .= $this->read(4);
		}

		$size = $compressed_bytes[$comp_fractional];
		if($size > 0) {
			$data .= $this->read($size);
		}

		return $data;

		
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
			#ECHO "LONG: " . $this->cast($d) . "\n";
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
			return $this->read_lpstring(($metadata->max_length > 255 ? 2 : 1));
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
			return $this->read_newdecimal($metadata->precision, $metadata->scale);
			default: die("DO NOT KNOW HOW TO READ TYPE: $data_type\n");
		}

		return false;
	}
			
}
