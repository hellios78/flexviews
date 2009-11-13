#!/bin/bash
while [ 1 ]
do
	php consumer
	echo "sleeping(3)..."
        sleep 1
	echo "sleeping(2)..."
        sleep 1
	echo "sleeping(1)..."
        sleep 1
done

