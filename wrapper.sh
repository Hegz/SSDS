#!/bin/bash

cd /home/otto

while true; do
	echo === Starting presentation ====
	/home/otto/ssds/presentation.sh 2>&1 | while read line; do echo [$(date)] - $line; done | tee -a log/$(date -I).txt
done
