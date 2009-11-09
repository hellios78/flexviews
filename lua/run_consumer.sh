. env.sh

#!/bin/bash
while [ 1 ]
do
	lua consumer.lua
	echo "sleeping..."
        sleep 10
done

