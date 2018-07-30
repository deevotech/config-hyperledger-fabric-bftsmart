#!/bin/bash
usage() { echo "Usage: $0 [-c <channelname>]" 1>&2; exit 1; }
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
echo "create channel"

DATA=/home/ubuntu/hyperledgerconfig/data
export FABRIC_CFG_PATH=$DATA/
PEER_ORGS="org1 org2"
NUM_PEERS=2
CHANNEL_NAME=${c}
CHANNEL_TX_FILE=$DATA/$CHANNEL_NAME.tx

echo "Generating channel configuration transaction at $CHANNEL_TX_FILE"
$GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
if [ "$?" -ne 0 ]; then
echo "Failed to generate channel configuration transaction"
  fi

for ORG in $PEER_ORGS; do
    ANCHOR_TX_FILE=$DATA/orgs/$ORG/anchors.tx
    echo  "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
 $GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE -channelID $CHANNEL_NAME -asOrg $ORG
 if [ "$?" -ne 0 ]; then
    echo "Failed to generate anchor peer update for $ORG"
 fi
done

echo "join channel to chain"
CA_CHAINFILE=${DATA}/org0-ca-cert.pem
ORDERER_HOST=orderer1-org0
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $CA_CHAINFILE --clientauth"
#initPeerVars ${PORGS[0]} 1
PEER_NAME=peer1-org1
PEER_HOST=$PEER_NAME
export FABRIC_CA_CLIENT=$DATA/peer1-org1/
export CORE_PEER_ID=peer1-org1
export CORE_PEER_ADDRESS=peer1-org1:7051
export CORE_PEER_LOCALMSPID=org1MSP
export CORE_LOGGING_LEVEL=DEBUG
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
export CORE_PEER_TLS_ROOTCERT_FILE=$DATA/org1-ca-cert.pem
export CORE_PEER_TLS_CLIENTCERT_FILE=$DATA/tls/$PEER_NAME-cli-client.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=$DATA/tls/$PEER_NAME-cli-client.key
export CORE_PEER_PROFILE_ENABLED=true
   # gossip variables
export CORE_PEER_GOSSIP_USELEADERELECTION=true
export CORE_PEER_GOSSIP_ORGLEADER=false
export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051

export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS

export CORE_PEER_MSPCONFIGPATH=$DATA/orgs/org1/admin/msp

echo "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ..."
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS

#sleep 5
# All peers join the channel
echo "ALL peers join the channel"
for ORG in $PEER_ORGS; do
     COUNT=1
     while [[ "$COUNT" -le $NUM_PEERS ]]; do
         #initPeerVars $ORG $COUNT
         PEER_HOST=peer${COUNT}-${ORG}
         #PEER_HOST=peer1-${ORG}
         PEER_NAME=${PEER_HOST}
         ORG_ADMIN_HOME=$DATA/orgs/$ORG/admin
         CA_CHAINFILE=${DATA}/${ORG}-ca-cert.pem
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
        if [ $COUNT -gt 1 ]; then
      		# Point the non-anchor peers to the anchor peer, which is always the 1st peer
      		export CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051
   		fi
         C=1
		   MAX_RETRY=10
		   while true; do
		      echo "Peer $PEER_HOST is attempting to join channel '$CHANNEL_NAME' (attempt #${C}) ..."
		      $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer channel join -b $CHANNEL_NAME.block
		      if [ $? -eq 0 ]; then
		         echo "Peer $PEER_HOST successfully joined channel '$CHANNEL_NAME'"
		         break
		      fi
		      if [ $C -gt $MAX_RETRY ]; then
		         echo "Peer $PEER_HOST failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
		      fi
		      C=$((C+1))
		      sleep 2
		   done
         COUNT=$((COUNT+1))
     done
done

sleep 5 
# Update the anchor peers
for ORG in $PEER_ORGS; do
    #initPeerVars $ORG 1
    #switchToAdminIdentity
    PEER_HOST=peer1-${ORG}
         PEER_NAME=${PEER_HOST}
         ORG_ADMIN_HOME=$DATA/orgs/$ORG/admin
         CA_CHAINFILE=${DATA}/${ORG}-ca-cert.pem
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
    echo "Updating anchor peers for $PEER_HOST ..."
    export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
    export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
    ANCHOR_TX_FILE=$DATA/orgs/$ORG/anchors.tx
    echo $ORDERER_CONN_ARGS
    $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
    sleep 2
done

