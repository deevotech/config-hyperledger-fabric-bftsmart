#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

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
source $(dirname "$0")/env.sh
ORG=${g}
mkdir -p ${DATA}
initPeerVars $ORG ${n}
export ENROLLMENT_URL=https://peer${n}-${ORG}:peer${n}-${ORG}pw@rca-${ORG}:7054
export PEER_HOME=${DATA}/${PEER_NAME}
export CORE_PEER_TLS_CERT_FILE=${DATA}/${PEER_NAME}/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${DATA}/${PEER_NAME}/tls/server.key
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=$DATA/${ORG}-ca-cert.pem
export CORE_PEER_TLS_CLIENTCERT_FILE=$DATA/${PEER_NAME}/tls/peer${n}-${ORG}-client.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=$DATA/${PEER_NAME}/tls/peer${n}-${ORG}-client.key
export FABRIC_CA_CLIENT_TLS_CERTFILES=$DATA/${ORG}-ca-cert.pem
export CORE_PEER_GOSSIP_SKIPHANDSHAKE=true

export CORE_PEER_TLS_ROOTCERT_FILE=${DATA}/${ORG}-ca-cert.pem
export CORE_PEER_TLS_KEY_FILE=${DATA}/peer${n}-${ORG}/tls/server.key
export CORE_PEER_GOSSIP_ORGLEADER=false
export CORE_PEER_LOCALMSPID=${ORG}MSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_ID=${PEER_NAME}
export CORE_LOGGING_LEVEL=DEBUG
export CORE_PEER_GOSSIP_EXTERNALENDPOINT=${PEER_NAME}:7051
export CORE_PEER_ADDRESS=${PEER_NAME}:7051
export CORE_PEER_GOSSIP_USELEADERELECTION=true
export FABRIC_CFG_PATH=${DATA}/
export CORE_PEER_MSPCONFIGPATH=$DATA/$PEER_NAME/msp


# Start the peer
log "Starting peer '$CORE_PEER_ID' with MSP at '$CORE_PEER_MSPCONFIGPATH'"
mkdir -p $DATA/$PEER_NAME
env | grep CORE > $DATA/$PEER_NAME/core.config
env | grep CORE

#cp -R $FABRIC_CA_CLIENT_HOME/* $DATA/$PEER_NAME/

if [ -f ./data/logs/${PEER_NAME}.out ] ; then
rm ./data/logs/${PEER_NAME}.out
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
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer node start > data/logs/${PEER_NAME}.out 2>&1 &
echo "success see in data/logs/peer1-org1.out"
