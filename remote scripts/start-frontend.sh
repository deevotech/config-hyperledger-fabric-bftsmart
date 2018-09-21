#!/bin/bash

function startFrontend {
    ssh -i '/var/ssh-keys/dev-full-rights.pem' ubuntu@18.136.194.250 "
    killall java
    cd /opt/gopath/src/github.com/hyperledger/hyperledger-bftsmart
    ./startFrontend.sh 1000 10 9999 > /tmp/logs/fronend.out 2>&1 &
    exit
    ";
}

startFrontend
