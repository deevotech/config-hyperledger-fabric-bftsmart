#!/bin/bash
#set -e

#SDIR=$(dirname "$0")
#source $SDIR/env.sh
DATA=/home/ubuntu/hyperledgerconfig/data
GENESIS_BLOCK_FILE=$DATA/genesis.block
export FABRIC_CFG_PATH=$DATA/
echo $FABRIC_CFG_PATH
cp ../config/configtx.yaml ${FABRIC_CFG_PATH}/
$GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPBFTsmart -channelID testchainid -outputBlock $GENESIS_BLOCK_FILE
if [ "$?" -ne 0 ]; then
    fatal "Failed to generate orderer genesis block"
fi
echo "success"


