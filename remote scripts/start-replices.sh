#!/bin/bash

function startReplica {
    if [ $# -ne 2 ]; then
      echo "Usage: startReplica <HOST> <NUM>: $*"
    exit 1
    fi
    host=$1
    num=$2
    ssh -i '/var/ssh-keys/dev-full-rights.pem' ubuntu@${host} "
    killall java
    cd /opt/gopath/src/github.com/hyperledger/hyperledger-bftsmart
    ./startReplica.sh ${num} > /tmp/logs/replica.out 2>&1 &
    exit
    ";
}

startReplica 54.169.163.249 0
startReplica 13.250.13.77 1
startReplica 52.221.197.115 2
startReplica 52.221.192.195 3