#!/bin/bash
usage() { echo "Usage: $0 [-c <channelname>]" 1>&2; exit 1; }
DATA=/hyperledgerconfig/data
GENESIS_BLOCK_FILE=$DATA/genesis.block
export FABRIC_CFG_PATH=$DATA/
while getopts ":c:" o; do
    case "${o}" in
        c)
            c=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "${c}" ] ; then
    usage
fi
$GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPBFTsmart -outputBlock $GENESIS_BLOCK_FILE -channelID genesischannel
if [ "$?" -ne 0 ]; then
    fatal "Failed to generate orderer genesis block"
fi
echo "success"


