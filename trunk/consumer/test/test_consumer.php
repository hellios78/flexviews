<?php 
require_once('../consumer.php');

class ConsumerTest extends PHPUnit_Framework_TestCase
{   
    public function testConstructor() {
    
	$settings = parse_ini_file('./test_consumer.ini', true);
        $cdc = new FlexCDC($settings);
        $this->assertEquals('FlexCDC', get_class($cdc));
 
        $this->assertTrue($cdc->get_source() && $cdc->get_dest());
        
        return $cdc;
        
    }
 
    /**
     * @depends testConstructor
     */
    public function testAutochangelog($cdc)
    {   
    	$conn = $cdc->get_source();
    	$this->assertFalse(!mysql_query('RESET MASTER', $conn));
        $this->assertTrue(mysql_query('DROP DATABASE IF EXISTS test', $conn));
        $this->assertTrue(mysql_query('CREATE DATABASE test', $conn));
        $this->assertTrue(mysql_query('CREATE TABLE test.t1(c1 int) engine=innodb', $conn));                
        $this->assertTrue(mysql_query('INSERT INTO test.t1(c1) values (1),(2),(3)', $conn));
        
        $cdc->capture_changes();
    
    }
 
    
}

?>
