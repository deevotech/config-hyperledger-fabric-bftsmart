#!/bin/bash

DATA=/home/ubuntu/hyperledgerconfig/data
ORG=org1
CHANNEL_NAME=channel1
CHAINCODE_NAME=cc1
PEER_HOST=peer1-${ORG}
PEER_NAME=${PEER_HOST}
export ORG_ADMIN_HOME=$DATA/orgs/$ORG/admin
export CA_CHAINFILE=${DATA}/${ORG}-ca-cert.pem
export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
export CORE_PEER_ID=$PEER_HOST
export CORE_PEER_ADDRESS=$PEER_HOST:7051
export CORE_PEER_LOCALMSPID=${ORG}MSP
export CORE_LOGGING_LEVEL=DEBUG
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
export CORE_PEER_TLS_CLIENTCERT_FILE=$DATA/tls/$PEER_NAME-cli-client.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=$DATA/tls/$PEER_NAME-cli-client.key
export CORE_PEER_PROFILE_ENABLED=true
# gossip variables
export CORE_PEER_GOSSIP_USELEADERELECTION=true
export CORE_PEER_GOSSIP_ORGLEADER=false
echo "Updating anchor peers for ${PEER_HOST} ..."
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS

echo "Sending invoke transaction to $PEER_HOST ..."
${GOPATH}/src/github.com/hyperledger/fabric/build/bin/peer chaincode invoke -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v 1.0 -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS
exit
