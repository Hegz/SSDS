#!/bin/bash

cd /home/ubuntu

while true; do
	echo === Starting presentation ====
	/home/ubuntu/presentation.sh 2>&1 | while read line; do echo [$(date)] - $line; done | tee -a log/$(date -I).txt
done
