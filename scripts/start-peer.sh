#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
usage() {
	echo "Usage: $0 [-g <orgname>] [-n <numberpeer>]" 1>&2
	exit 1
}
while getopts ":g:n:" o; do
	case "${o}" in
	g)
		g=${OPTARG}
		;;
	n)
		n=${OPTARG}
		;;
	*)
		usage
		;;
	esac
done
shift $((OPTIND - 1))
if [ -z "${g}" ] || [ -z "${n}" ]; then
	usage
fi
ORG=${g}
NUMBER=${n}
DATA=/home/ubuntu/hyperledgerconfig/data
PEER_NAME=peer${NUMBER}-${ORG}
export PEER_GOSSIP_SKIPHANDSHAKE=true
export CORE_PEER_TLS_CLIENTCERT_FILE=${DATA}/tls/${PEER_NAME}-client.crt
export CORE_PEER_TLS_ROOTCERT_FILE=${DATA}/${ORG}-ca-cert.pem
export CORE_PEER_TLS_KEY_FILE=${DATA}/${PEER_NAME}/tls/server.key
export CORE_PEER_GOSSIP_ORGLEADER=false
export CORE_PEER_LOCALMSPID=${ORG}MSP
#export CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
export CORE_PEER_TLS_CERT_FILE=${DATA}/${PEER_NAME}/tls/server.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${DATA}/${ORG}-ca-cert.pem
export CORE_PEER_TLS_CLIENTKEY_FILE=${DATA}/tls/${PEER_NAME}-client.key
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_MSPCONFIGPATH=${DATA}/${PEER_NAME}/msp
#export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=bftsmartnetwork_fabric-ca-orderer-bftsmart
export CORE_PEER_ID=${PEER_NAME}
export CORE_LOGGING_LEVEL=DEBUG
export CORE_PEER_GOSSIP_EXTERNALENDPOINT=${PEER_NAME}:7051
export CORE_PEER_ADDRESS=${PEER_NAME}:7051
export CORE_PEER_GOSSIP_USELEADERELECTION=true
if [ $NUMBER -gt 1 ]; then
	export CORE_PEER_GOSSIP_BOOTSTRAP=peer${NUMBER}-${ORG}:7051
	export CORE_PEER_ADDRESSAUTODETECT=true
fi

export FABRIC_CFG_PATH=${DATA}/
cp ../config/core-${PEER_NAME}.yaml ${DATA}/core.yaml
mkdir -p data
mkdir -p data/logs
if [ -f ./data/logs/${PEER_NAME}.out ]; then
	rm ./data/logs/${PEER_NAME}.out
fi
if [ -d /var/hyperledger/production ]; then
	rm -rf /var/hyperledger/production/*
fi
chaincodeImages=$(docker images | grep "^dev-peer" | awk '{print $3}')
if [ "$chaincodeImages" != "" ]; then
	# log "Removing chaincode docker images ..."
	docker rmi -f $chaincodeImages >/dev/null
fi
# remove couchdb database
# restart couchdb server
#sudo kill $(pidof runsv)
sudo sv stop /etc/service/couchdb
if [ -f /etc/service/couchdb/supervise/lock ]; then
	sudo rm /etc/service/couchdb/supervise/lock
fi
if [ -d /opt/couchdb ]; then
	sudo rm -rf /opt/couchdb
fi
sudo mkdir /opt/couchdb
sudo mkdir /opt/couchdb/data
sudo chmod 777 -R /opt/couchdb
sudo cp ./local.ini /home/couchdb/etc/local.ini
rm -rf /ect/sv/couchdb/log/*

#sudo runsv /etc/service/couchdb
sudo sv start /etc/service/couchdb
sleep 5
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer node start >data/logs/${PEER_NAME}.out 2>&1 &
echo "Success see in data/logs/${PEER_NAME}.out"
