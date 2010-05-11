<?php

require_once('consumer.php');
$cdc = new FlexCDC();
#TODO: daemonize on unix
#capture changes forever (-1):
$cdc->capture_changes(-1);
