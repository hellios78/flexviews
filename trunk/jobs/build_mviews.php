<?php

# build_mviews.php
# connect to the specified MySQL server and spawn a child to refresh each
# materialized view

define('SERVER',"127.0.0.1");
define('USER',"");
define('PASS',"");
define('DB',"flexviews");

main();

function get_conn() {
   return(mysqli_connect(SERVER, USER, PASS, DB));
}

function log_and_die($message) {
  echo date('r') . "\t$message\n";
  die($message);
}

function refresh_mview($mview_id) {
  $sql = "CALL mview_refresh($mview_id)";
  $conn = get_conn();
  if (!$conn) log_and_die(mysqli_connect_error());

  $stmt = mysqli_query($conn,$sql);
  if (!$stmt) log_and_die(mysqli_error($conn));
}

function main() {
  $conn = get_conn();

  if (!$conn) log_and_die(mysqli_connect_error());

  $sql = "select * from mview_refresh_status where mview_next_refresh < now()";
  $stmt = mysqli_query($conn,$sql);

  if (!$stmt) log_and_die(mysqli_error($conn));

  while ($row = mysqli_fetch_assoc($stmt)) {
    $pid = pcntl_fork();

    if ($pid == 0) {
      refresh_mview($row['mview_id']);
      exit;
    }

  }
}
?>
