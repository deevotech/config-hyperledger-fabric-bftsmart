#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

usage() { echo "Usage: $0 [-g <orgname>] [-n <numberpeer>]" 1>&2; exit 1; }
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
shift $((OPTIND-1))
if [ -z "${g}" ] || [ -z "${n}" ] ; then
    usage
fi
ORG=${g}
DATA=/home/ubuntu/hyperledgerconfig/data
export CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
export CORE_PEER_TLS_CLIENTCERT_FILE=${DATA}/tls/peer${n}-${ORG}-client.crt
export CORE_PEER_TLS_ROOTCERT_FILE=${DATA}/${ORG}-ca-cert.pem
export CORE_PEER_TLS_KEY_FILE=${DATA}/peer${n}-${ORG}/tls/server.key
export CORE_PEER_GOSSIP_ORGLEADER=false
export CORE_PEER_LOCALMSPID=${ORG}MSP
#export CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
export CORE_PEER_TLS_CERT_FILE=${DATA}/peer${n}-${ORG}/tls/server.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${DATA}/${ORG}-ca-cert.pem
export CORE_PEER_TLS_CLIENTKEY_FILE=${DATA}/tls/peer${n}-${ORG}-client.key
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_MSPCONFIGPATH=${DATA}/peer${n}-${ORG}/msp
#export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=bftsmartnetwork_fabric-ca-orderer-bftsmart
export CORE_PEER_ID=peer${n}-${ORG}
export CORE_LOGGING_LEVEL=DEBUG
export CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer${n}-${ORG}:7051
export CORE_PEER_ADDRESS=peer${n}-${ORG}:7051
export CORE_PEER_GOSSIP_USELEADERELECTION=true
export FABRIC_CFG_PATH=${DATA}/
export CORE_PEER_ADDRESSAUTODETECT=false
if [ ${n} -gt 1 ] ; then
export CORE_PEER_GOSSIP_BOOTSTRAP=peer${n}-${ORG}:7051
fi


# Start the peer

#cp -R $FABRIC_CA_CLIENT_HOME/* $DATA/$PEER_NAME/

if [ -f ./data/logs/${CORE_PEER_ID}.out ] ; then
rm ./data/logs/${CORE_PEER_ID}.out
fi
if [ -d /var/hyperledger/production ] ; then
rm -rf /var/hyperledger/production/*
fi
chaincodeImages=`docker images | grep "^dev-peer" | awk '{print $3}'`
if [ "$chaincodeImages" != "" ]; then
  # log "Removing chaincode docker images ..."
   docker rmi -f $chaincodeImages > /dev/null
fi
mkdir -p data
mkdir -p data/logs
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer node start > data/logs/${CORE_PEER_ID}.out 2>&1 &
echo "success see in data/logs/peer1-org1.out"
