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
ENROLLMENT_URL=https://peer${n}-${ORG}:peer${n}-${ORG}pw@ica-org1:7054

# Although a peer may use the same TLS key and certificate file for both inbound and outbound TLS,
# we generate a different key and certificate for inbound and outbound TLS simply to show that it is permissible
mkdir -p /tmp/tls
# Generate server TLS cert and key pair for the peer
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
mkdir -p /data/$PEER_NAME
env | grep CORE > /data/$PEER_NAME/core.config
env | grep CORE

cp -R $FABRIC_CA_CLIENT_HOME/* $DATA/$PEER_NAME/

if [ -f ./data/logs/${PEER_NAME}.out ] ; then
rm ./data/logs/${PEER_NAME_NAME}.out
fi
if [ -d /var/hyperledger/production ] ; then
rm -rf /var/hyperledger/production/*
fi
chaincodeImages=`docker images | grep "^dev-peer" | awk '{print $3}'`
if [ "$chaincodeImages" != "" ]; then
  # log "Removing chaincode docker images ..."
   docker rmi -f $chaincodeImages > /dev/null
fi
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer node start > data/logs/${HOST_NAME}.out 2>&1 &
echo "success see in data/logs/peer1-org1.out"
