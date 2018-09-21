#!/bin/bash

function stop {
    if [ $# -ne 1 ]; then
      echo "Usage: startReplica <HOST>: $*"
    exit 1
    fi
    host=$1
    ssh -i '/var/ssh-keys/dev-full-rights.pem' ubuntu@${host} "
    killall java
    exit
    ";
}
stop 54.169.163.249 
stop 13.250.13.77 
stop 52.221.197.115 
stop 52.221.192.195 
stop 18.136.194.250