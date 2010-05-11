<?php

require_once('consumer.php');
$cdc = new FlexCDC();

#this will read settings from the INI file and initialize
#the database and capture the source master position
$cdc->setup();

?>
