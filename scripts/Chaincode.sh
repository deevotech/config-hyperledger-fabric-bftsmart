#!/bin/bash
usage() { echo "Usage: $0 [-c <channelname>] -n [chaincodename]" 1>&2; exit 1; }
while getopts ":c:n:" o; do
    case "${o}" in
        c)
            c=${OPTARG}
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
if [ -z "${c}" ] || [ -z "${n}" ] ; then
    usage
fi
echo "create channel channelID ${c} chaincodeName ${n} "

DATA=/home/ubuntu/hyperledgerconfig/data
export FABRIC_CFG_PATH=$DATA/
PEER_ORGS="org1 org2"
NUM_PEERS=2
CHANNEL_NAME=${c}
CHANNEL_TX_FILE=$DATA/$CHANNEL_NAME.tx
CA_CHAINFILE=${DATA}/org0-ca-cert.pem
ORDERER_HOST=orderer1-org0
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls true --cafile $CA_CHAINFILE --clientauth"
QUERY_TIMEOUT=30

# Config block file path
CONFIG_BLOCK_FILE=/tmp/config_block.pb

# Update config block payload file path
CONFIG_UPDATE_ENVELOPE_FILE=/tmp/config_update_as_envelope.pb

function chaincodeQuery {
   if [ $# -ne 1 ]; then
      fatalr "Usage: chaincodeQuery <expected-value>"
   fi
   set +e
   echo "Querying chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' ..."
   local rc=1
   local starttime=$(date +%s)
   # Continue to poll until we get a successful response or reach QUERY_TIMEOUT
   while test "$(($(date +%s)-starttime))" -lt "$QUERY_TIMEOUT"; do
      sleep 3
      $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode query -C $CHANNEL_NAME -n ${n} -v 1.0 -c '{"Args":["query","a"]}' >& data/logs/query-logs.txt
      VALUE=$(cat data/logs/query-logs.txt | awk '/Query Result/ {print $NF}')
      if [ $? -eq 0 -a "$VALUE" = "$1" ]; then
         echo "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
         set -e
         return 0
      else
         # removed the string "Query Result" from peer chaincode query command result, as a result, have to support both options until the change is merged.
         VALUE=$(cat data/logs/query-logs.txt | egrep '^[0-9]+$')
         if [ $? -eq 0 -a "$VALUE" = "$1" ]; then
            echo "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
            set -e
            return 0
         fi
      fi
      echo -n "."
   done
   echo "Failed to query channel '$CHANNEL_NAME' on peer '$PEER_HOST'; expected value was $1 and found $VALUE"
}

function installChaincode {
   #switchToAdminIdentity
   echo "Installing chaincode on $PEER_HOST ..."
   $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go
}
function fetchConfigBlock {
   echo "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer channel fetch config $CONFIG_BLOCK_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}
function updateConfigBlock {
   echo "Updating the configuration block of the channel '$CHANNEL_NAME'"
   $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer channel update -f $CONFIG_UPDATE_ENVELOPE_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}
function createConfigUpdatePayloadWithCRL {
   log "Creating config update payload with the generated CRL for the organization '$ORG'"
   # Start the configtxlator
   configtxlator start &
   configtxlator_pid=$!
   log "configtxlator_pid:$configtxlator_pid"
   log "Sleeping 5 seconds for configtxlator to start..."

   pushd /tmp

   CTLURL=http://127.0.0.1:7059
   # Convert the config block protobuf to JSON
   curl -X POST --data-binary @$CONFIG_BLOCK_FILE $CTLURL/protolator/decode/common.Block > config_block.json
   # Extract the config from the config block
   jq .data.data[0].payload.data.config config_block.json > config.json

   # Update crl in the config json
   CRL=$(cat $CORE_PEER_MSPCONFIGPATH/crls/crl*.pem | base64 | tr -d '\n')
   cat config.json | jq --arg org "$ORG" --arg crl "$CRL" '.channel_group.groups.Application.groups[$org].values.MSP.value.config.revocation_list = [$crl]' > updated_config.json

   # Create the config diff protobuf
   curl -X POST --data-binary @config.json $CTLURL/protolator/encode/common.Config > config.pb
   curl -X POST --data-binary @updated_config.json $CTLURL/protolator/encode/common.Config > updated_config.pb
   curl -X POST -F original=@config.pb -F updated=@updated_config.pb $CTLURL/configtxlator/compute/update-from-configs -F channel=$CHANNEL_NAME > config_update.pb

   # Convert the config diff protobuf to JSON
   curl -X POST --data-binary @config_update.pb $CTLURL/protolator/decode/common.ConfigUpdate > config_update.json

   # Create envelope protobuf container config diff to be used in the "peer channel update" command to update the channel configuration block
   echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' > config_update_as_envelope.json
   curl -X POST --data-binary @config_update_as_envelope.json $CTLURL/protolator/encode/common.Envelope > $CONFIG_UPDATE_ENVELOPE_FILE

   # Stop configtxlator
   kill $configtxlator_pid

   popd
}
#function revokeFabricUserAndGenerateCRL {
   #switchToAdminIdentity
   #export  FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
   #logr "Revoking the user '$USER_NAME' of the organization '$ORG' with Fabric CA Client home directory set to $FABRIC_CA_CLIENT_HOME and generating CRL ..."
   #export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   #fabric-ca-client revoke -d --revoke.name $USER_NAME --gencrl
#}
# install chaincode on peer1-org1, peer1-org2
for ORG in $PEER_ORGS; do
    #initPeerVars $ORG 1
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
    export CORE_PEER_GOSSIP_ORGLEADER=false
    echo "Install for $PEER_HOST ..."
    export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls true --cafile $DATA/org0-ca-cert.pem --clientauth"
    export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
    echo $ORDERER_CONN_ARGS
    $GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode install -n $n -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go
    #$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode install -n ${n} -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02
    #sleep 3
done
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode list --installed -C $CHANNEL_NAME
# Instantiate chaincode on the 1st peer of the 2nd org
#makePolicy
POLICY="OR ('org1MSP.member', 'org2MSP.member')"
echo "policy: $POLICY"
#initPeerVars ${PORGS[1]} 1
#switchToAdminIdentity
ORG=org1
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
export CORE_PEER_GOSSIP_ORGLEADER=false
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS

echo "Instantiating chaincode on $PEER_HOST ..."
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode instantiate -C $CHANNEL_NAME -n ${n} -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "$POLICY" $ORDERER_CONN_ARGS

# Query chaincode from the 1st peer of the 1st org
#initPeerVars ${PORGS[0]} 1
ORG=org2
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
export CORE_PEER_GOSSIP_ORGLEADER=false
echo "Query $PEER_HOST ..."
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS
#switchToUserIdentity
#change switchToAdminIdentity
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode list --instantiated -C $CHANNEL_NAME $ORDERER_CONN_ARGS
chaincodeQuery 100

#initPeerVars ${PORGS[0]} 1
#switchToUserIdentity
ORG=org1
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
export CORE_PEER_GOSSIP_ORGLEADER=false
echo "Updating anchor peers for $PEER_HOST ..."
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS

echo "Sending invoke transaction to $PEER_HOST ..."
$GOPATH/src/github.com/hyperledger/fabric/build/bin/peer chaincode invoke -C $CHANNEL_NAME -n ${n} -v 1.0 -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS

# Query chaincode from the 1st peer of the 1st org
#initPeerVars ${PORGS[0]} 1
ORG=org1
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
export CORE_PEER_GOSSIP_ORGLEADER=false
echo "Updating anchor peers for $PEER_HOST ..."
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS
#switchToUserIdentity
#change switchToAdminIdentity
chaincodeQuery 90
echo "done"

## Install chaincode on 2nd peer of 2nd org
#initPeerVars ${PORGS[1]} 2
ORG=org2
PEER_HOST=peer2-${ORG}
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
export CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS
installChaincode

## Query chaincode on 2nd peer of 2nd org
#initPeerVars ${PORGS[1]} 2
#switchToUserIdentity
ORG=org2
PEER_HOST=peer2-${ORG}
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
export CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051
export ORDERER_PORT_ARGS=" -o orderer1-org0:7050 --tls --cafile $DATA/org0-ca-cert.pem --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
echo $ORDERER_CONN_ARGS
chaincodeQuery 90

#initPeerVars ${PORGS[0]} 1
#switchToUserIdentity

# Revoke the user and generate CRL using admin's credentials
#revokeFabricUserAndGenerateCRL

# Fetch config block
fetchConfigBlock

# Create config update envelope with CRL and update the config block of the channel
#createConfigUpdatePayloadWithCRL
#updateConfigBlock

# querying the chaincode should fail as the user is revoked
#switchToUserIdentity
#queryAsRevokedUser
#if [ "$?" -ne 0 ]; then
  #logr "The revoked user $USER_NAME should have failed to query the chaincode in the channel '$CHANNEL_NAME'"
  #exit 1
#fi
echo "Congratulations! The tests ran successfully."
