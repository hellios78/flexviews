<?php

#the plan is to do a VERY simple tokenizer and "parser" for the SQL statement
#this is VERY limitied and will only work for queries of the type:
#SELECT t1.a, t2.b, sum(t1.a)
#  FROM db.t1 as t1
#  JOIN db.t2 on (t1.id = t1_id)
#WHERE 1=1
#GROUP BY t1.a, t2.b
#
#to produce
# call flexviews.add_table(@mvid, 'db', 't1', 't1' ,NULL);
# call flexviews.add_table(@mvid, 'db', 't2', 't2, ' on (t1.id = t1_id)'
# call flexviews.add_expr(@mvid, 'GROUP', 't1.a', 't1_a');
# call flexviews.add_expr(@mvid, 'GROUP', 't2.b', 't2_b');
# call flexviews.add_expr(@mvid, 'SUM', 't1.a', 'sum_t1_a');
# call flexviews.add_expr(@mvid, 'WHERE', '1=1', 'where1');

# the output may need massaging



function tokenize($sql) {
  if(!$sql) return;
  $sql = trim($sql, ';');

$regex = <<<'END_OF_REGEX'
/
  [A-Za-z_.]+\(.*?\)+   # Match FUNCTION(...)
  |\(.*?\)+             # Match grouped items
  |"[^"](?:|\"|"")*?"+
  |'[^'](?:|\'|'')*?'+
  |`(?:[^`]|``)*`+
  |[^ ,]+
  |,
/x
END_OF_REGEX;

  preg_match_all($regex, $sql, $matches);
  return($matches[0]);

}

function process_select($tok) {
  $expr = "";
  for($i=1;$i<count($tok);++$i) {
    $exprType = 'GROUP';
    $token = trim($tok[$i]);
    if(!$expr) $expr = $token;
    if($token == ',' || strtolower($token) == 'from') { 
        $alias = preg_replace('/[^A-Za-z0-9`]/','_',$tok[$i-1]);
        if(preg_match('/(sum|min|max|avg|count)\((.*)\)/i', $expr, $matches)) {
          $expr = $matches[2];
          $exprType = strtoupper($matches[1]);
        }
        if($expr[0] != "'" && $expr[0] != '"') $expr = "'". mysql_escape_string($expr) . "'";
#	echo "EXPR_TYPE: $exprType EXPR: $expr  ALIAS: $alias \n";
        echo "call flexviews.add_expr(@mvid, '$exprType', $expr, '$alias');\n";
        $expr = "";
    }
    if(strtolower($token) == 'from') return $i;
  }
 
  return false;
}

function process_sql($sql) {

  if(substr($sql,0,2) == "--") {
    $info = explode(':', $sql);
    $table=trim($info[1]);
    echo "-- Flexview start\n";
    #FIXME: parse database.tablename
    echo("call flexviews.create('DEST_DATABASE.', '$table', 'INCREMENTAL');\n");
    echo("SET @mvid := LAST_INSERT_ID();\n");
  } else {
    echo "-- $sql\n";
  }

  $tok = tokenize($sql);
  $from = process_select($tok);
  if($from !== false) {
    echo "call flexviews.add_table(@mv_id,'kfpw_orbus_metrics', '{$tok[$from+1]}', 'the_tbl', NULL);\n";
  }
  echo "\n";
}

function main() {
  #get the query from stdin
  $fh = fopen('php://stdin', 'r');
  $sql = "";
  #read all the lines from the file and combine into a single
  #line SQL statement with no carriage returns and limited extra whitespace
  while($line = fgets($fh)) {
  
    if(feof($fh)) break;
  
    $line = trim($line);
  
    # a new SQL statement is starting
    if (substr($line,0,6) == 'SELECT' || substr($line,0,2) == '--') {
      #send any existing SQL statement to the processor
      process_sql($sql);
      $sql = $line;
    } elseif ($sql) {
      #append to the existing statement
      $sql .= " " . $line;
    } else {
      #start new SQL statement
      $sql = $line; 
    }
  }
  $tokens = tokenize($sql);
  process_sql($sql);
  return;
}

#start of program
main();

#end of program
exit;

