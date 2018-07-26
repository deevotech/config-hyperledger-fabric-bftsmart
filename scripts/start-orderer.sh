#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
set -e

source $(dirname "$0")/env.sh

# Wait for setup to complete sucessfully
usage() { echo "Usage: $0 [-g <orgname>]" 1>&2; exit 1; }
while getopts ":g::" o; do
    case "${o}" in
        g)
            g=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "${g}" ] ; then
    usage
fi
source $(dirname "$0")/env.sh
ORG=${g}
mkdir -p ${DATA}
initOrdererVars $ORG

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

