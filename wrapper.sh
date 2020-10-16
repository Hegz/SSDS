#!/bin/bash

cd /home/ubuntu

while true; do
	/home/ubuntu/presentation.sh 2>&1 | while read line; do echo [$(date)] - $line; done | tee -a $(date -I).txt
done
