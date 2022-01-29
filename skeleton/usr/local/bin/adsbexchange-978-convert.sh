#!/bin/bash

SO_OPTIONS="keepalive,keepidle=30,keepintvl=30,keepcnt=2"
while sleep 5
do
	socat -d -u "TCP:localhost:30978,$SO_OPTIONS" STDOUT | uat2esnt | socat -d -u STDIN "TCP:localhost:37981,$SO_OPTIONS"
done
