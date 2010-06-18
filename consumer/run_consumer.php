<?php
require_once('Console/Getopt.php');
#
#if(!function_exists('pcntl_fork')) {
#	function pcntl_fork() {
#		die("The --daemon option requires the pctnl extension.\n");
#	}
#}

function &get_commandline() {

        $cg = new Console_Getopt();
        $args = $cg->readPHPArgv();
        array_shift($args);

        $shortOpts = 'h::v::';
        $longOpts  = array('ini=', 'help==', 'pid=', 'daemon==' );

        $params = $cg->getopt2($args, $shortOpts, $longOpts);
        if (PEAR::isError($params)) {
            echo 'Error: ' . $params->getMessage() . "\n";
            exit(1);
        }
        $new_params = array();
        foreach ($params[0] as $param) {
                $param[0] = str_replace('--','', $param[0]);
                $new_params[$param[0]] = $param[1];
        }
        unset($params);

        return $new_params;
}

$params = get_commandline();
$settings = false;

#support specifying location of .ini file on command line
if(!empty($params['ini'])) {
	$settings = @parse_ini_file($params['ini'], true);
}

#support pid file
if(!empty($params['pid'])) {
	if(file_exists($params['pid'])) {
		$pid = trim(file_get_contents($params['pid']));
		$exists = `ps -p $pid`;
		$exists = explode('\n', $exists);
		if(count($exists) > 1) {
			die('Already running!\n');
		} else {
			echo "Stale lockfile detected.\n";
		}
	}
	file_put_contents($params['pid'], getmypid());
}

if(in_array('daemon', array_keys($params))) {
	$pid = pcntl_fork();
	if($pid == -1) {
		die('Could not fork a new process!\n');
	} elseif($pid == 0) {
		#we are now in a child process, and the capture_changes
	        #below will be daemonized
		$do_nothing = 1;
	} else {
		#return control to the shell
		exit();
	}
}

require_once('flexcdc.php');
$cdc = new FlexCDC($settings);
#TODO: daemonize on unix
#capture changes forever (-1):

$cdc->capture_changes(-1);
