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
mkdir -p $DATA/${PEER_NAME}
mkdir -p $DATA/${PEER_NAME}
if [ -d ${CORE_PEER_MSPCONFIGPATH}/keystore/] ; then
	rm -rf ${CORE_PEER_MSPCONFIGPATH}/keystore/*
fi

# Although a peer may use the same TLS key and certificate file for both inbound and outbound TLS,
# we generate a different key and certificate for inbound and outbound TLS simply to show that it is perssible
mkdir -p /tmp/tls
if [ -d /tmp/tls/keystore/ ] ; then
	rm -rf /tmp/tls/keystore/*
fi
# Generate server TLS cert and key pair for the peer
echo ${ENROLLMENT_URL}
echo ${PEER_HOST}
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $PEER_HOST


# Copy the TLS key and cert to the appropriate place
TLSDIR=$PEER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/signcerts/* $CORE_PEER_TLS_CERT_FILE
cp /tmp/tls/keystore/* $CORE_PEER_TLS_KEY_FILE
rm -rf /tmp/tls

# Generate client TLS cert and key pair for the peer
genClientTLSCert $PEER_NAME $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE

# Generate client TLS cert and key pair for the peer CLI
genClientTLSCert $PEER_NAME $DATA/tls/$PEER_NAME-cli-client.crt $DATA/tls/$PEER_NAME-cli-client.key

# Enroll the peer to get an enrollment certificate and set up the core's local MSP directory
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $CORE_PEER_MSPCONFIGPATH
finishMSPSetup $CORE_PEER_MSPCONFIGPATH
copyAdminCert $CORE_PEER_MSPCONFIGPATH


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
cp ${DATA}/${PEER_NAME}/tls/${PEER_NAME}-client.key ${DATA}/tls/
cp ${DATA}/${PEER_NAME}/tls/${PEER_NAME}-client.csr ${DATA}/tls/
cp ../config/core-peer${n}-${ORG}.yaml $DATA/core.yaml