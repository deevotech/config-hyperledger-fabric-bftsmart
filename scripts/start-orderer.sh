#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
set -e

source $(dirname "$0")/env.sh

# Wait for setup to complete sucessfully
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
initOrdererVars $ORG ${n}
export ORDERER_GENERAL_LOCALMSPDIR=${DATA}/orgs/msp
export ORDERER_GENERAL_GENESISFILE=${DATA}/orgs/genesis.block
export ORDERER_GENERAL_LOCALMSPID=${ORG}MSP
export ORDERER_GENERAL_TLS_ROOTCAS=[${DATA}/${ORG}-ca-cert.pem]
export ORDERER_GENERAL_TLS_CLIENTROOTCAS=[${DATA}/${ORG}-ca-cert.pem]
export ORDERER_HOST=orderer${n}-${ORG}
export ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
export ORDERER_GENERAL_TLS_PRIVATEKEY=${DATA}/orderer/tls/server.key
export ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true
export ORDERER_GENERAL_LOGLEVEL=debug
export ORDERER_GENERAL_GENESISMETHOD=file
#export ORDERER_DEBUG_BROADCASTTRACEDIR=/hyperledgerconfig/data/logs
export ORDERER_GENERAL_TLS_CERTIFICATE=${DATA}/orderer/tls/server.crt
export ORDERER_GENERAL_TLS_ENABLED=true
export ORDERER_HOME=${DATA}/orderer
export FABRIC_CFG_PATH=${DATA}/
export ORDERER_FILELEDGER_LOCATION=/var/hyperledger/production/orderer
export FABRIC_CA_CLIENT_HOME=$HOME/orderer
export FABRIC_CA_CLIENT_TLS_CERTFILES=${DATA}/${DATA}-ca-chain.pem
export ENROLLMENT_URL=https://${ORDERER_HOST}:${ORDERER_HOST}pw@rca-${ORG}:7054
export ORDERER_HOME=${DATA}/orderer
export ORDERER_GENERAL_TLS_CERTIFICATE=${DATA}/orderer/tls/server.crt
export ORDERER_DEBUG_BROADCASTTRACEDIR=$DATA/logs
export ORG=${g}
export ORG_ADMIN_CERT=${DATA}/orgs/org0/msp/admincerts/cert.pem


mkdir -p ${DATA}/orderer
mkdir -p ${DATA}/orderer/tls
rm -rf /var/hyperledger/production/*
mkdir -p data
mkdir -p data/logs
if [ -f ./data/logs/orderer.out ] ; then
rm ./data/logs/orderer.out
fi
export ENROLLMENT_URL=https://orderer${n}-${ORG}:orderer${n}-${ORG}pw@rca-${ORG}:7054
mkdir -p /tmp/tls
mkdir -p /tmp/tls/signcerts
mkdir -p /tmp/tls/keystore
# Enroll to get orderer's TLS cert (using the "tls" profile)
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $ORDERER_HOST

# Copy the TLS key and cert to the appropriate place
TLSDIR=$ORDERER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/keystore/* $ORDERER_GENERAL_TLS_PRIVATEKEY
cp /tmp/tls/signcerts/* $ORDERER_GENERAL_TLS_CERTIFICATE
rm -rf /tmp/tls

# Enroll again to get the orderer's enrollment certificate (default profile)
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR

# Finish setting up the local MSP for the orderer
finishMSPSetup $ORDERER_GENERAL_LOCALMSPDIR
copyAdminCert $ORDERER_GENERAL_LOCALMSPDIR
mkdir -p $DATA/orderer

env | grep ORDERER
rm -rf /var/hyperledger/production/*
mkdir -p data
mkdir -p data/logs
if [ -f ./data/logs/orderer.out ] ; then
rm ./data/logs/orderer.out
fi

$GOPATH/src/github.com/hyperledger/fabric/build/bin/orderer start > ./data/logs/orderer.out 2>&1 &
echo "done see /data/logs/orderer"

