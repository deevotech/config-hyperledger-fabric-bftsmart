#!/bin/bash
#

# Install go
sudo apt-get update &&
sudo apt-get -y upgrade &&
sudo curl -O https://storage.googleapis.com/golang/go1.10.4.linux-amd64.tar.gz
sudo tar -xf go1.10.4.linux-amd64.tar.gz
sudo mv go /opt
# sudo mkdir -p /opt/gopath
# sudo chmod 777 -R /opt/gopath

# Install JAVA
sudo apt -y install openjdk-8-jdk &&
update-java-alternatives --list

# Install ant
sudo apt-get update &&
sudo apt-get -y install ant &&

# Install juds
mkdir -p $GOPATH/src/github.com
cd $GOPATH/src/github.com
git clone https://github.com/mcfunley/juds
cd juds 
sudo apt-get -y install libc6-dev-i386 autoconf &&
./autoconf.sh
./configure
make
sudo make install

# Install Hyperledge Fabric + BFTSmart
# Compile Hyperledger Fabric
cd $GOPATH/src/github.com 
mkdir hyperledger
cd hyperledger
git clone https://github.com/deevotech/fabric -b release-1.2-deevo
cd fabric
sudo ./devenv/setupUbuntuOnPPC64le.sh
make dist-clean peer orderer configtxgen
# Compile Hyperledger BFTSmart 
cd $GOPATH/src/github.com/hyperledger
git clone https://github.com/deevotech/fabric-orderingservice -b release-1.2-deevo
mv fabric-orderingservice hyperledger-bftsmart
cd hyperledger-bftsmart
ant

# Install Fabric CA
cd $GOPATH/src/github.com/hyperledger
sudo apt install libtool libltdl-dev make
git clone https://github.com/deevotech/fabric-ca -b release-1.2-deevo
cd fabric-ca/cmd/fabric-ca-client
go build
cd ../fabric-ca-server
go build


