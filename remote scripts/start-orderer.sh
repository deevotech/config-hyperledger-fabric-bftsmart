ssh -i '/var/ssh-keys/dev-full-rights.pem' ubuntu@18.136.194.250 "
killall orderer
cd /opt/gopath/src/github.com/deevotech/config-hyperledger-fabric-bftsmart/scripts
./start-orderer.sh -g org0 -n 1
exit
";