#!/bin/bash
SLEEP_TIME=10

while [ 1 ]
do
	php consumer.php ./consumer.ini
	if [ $? -eq 0 ]; then
          let SLEEP_TIME=SLEEP_TIME+250000       
        else
          let SLEEP_TIME=10;
        fi;

        if [ $SLEEP_TIME -gt 5000000 ]; then
          let SLEEP_TIME=5000000;
        fi;
        usleep $SLEEP_TIME;
done

