function startPeer {
    if [ $# -ne 3 ]; then
      echo "Usage: startReplica <HOST> <ORG> <NUM>: $*"
    exit 1
    fi
    host=$1
    org=$2
    num=$3
    ssh -i '/var/ssh-keys/dev-full-rights.pem' ubuntu@${host} "
    killall peer
    cd /opt/gopath/src/github.com/deevotech/config-hyperledger-fabric-bftsmart/scripts
    export GOPATH=/opt/gopath
    ./start-peer.sh -g ${org} -n ${num} 
    exit
    ";
}

startPeer 54.169.163.249 org1 1
startPeer 13.250.13.77 org1 2
startPeer 52.221.197.115 org2 1
startPeer 52.221.192.195 org2 2