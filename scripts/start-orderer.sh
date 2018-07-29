#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
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
NUMBER=${n}
DATA=/home/ubuntu/hyperledgerconfig/data
export ORDERER_GENERAL_LOCALMSPDIR=${DATA}/orderer/msp
export ORDERER_GENERAL_GENESISFILE=${DATA}/genesis.block
export ORDERER_GENERAL_LOCALMSPID=${ORG}MSP
export ORDERER_GENERAL_TLS_ROOTCAS=[${DATA}/${ORG}-ca-cert.pem]
export ORDERER_GENERAL_TLS_CLIENTROOTCAS=[${DATA}/${ORG}-ca-cert.pem]
export ORDERER_HOST=orderer${NUMBER}-${ORG}
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
rm -rf /var/hyperledger/production/*
mkdir -p data
mkdir -p data/logs
if [ -f ./data/logs/orderer.out ] ; then
rm ./data/logs/orderer.out
fi

$GOPATH/src/github.com/hyperledger/fabric/build/bin/orderer start > ./data/logs/orderer.out 2>&1 &
echo "done see /data/logs/orderer"

