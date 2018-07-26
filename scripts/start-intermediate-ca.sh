#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
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
initOrgVars $ORG

set -e
export FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
export FABRIC_CA_SERVER_CA_NAME=ica-${ORG}
export FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=${DATA}/${ORG}-ca-cert.pem
export FABRIC_CA_SERVER_CSR_HOSTS=ica-${ORG}
export FABRIC_CA_SERVER_TLS_ENABLED=true
export FABRIC_CA_SERVER_DEBUG=true
export BOOTSTRAP_USER_PASS=ica-${ORG}-admin:ica-${ORG}-adminpw
export PARENT_URL=https://rca-${ORG}-admin:rca-${ORG}-adminpw@rca-${ORG}:7054
export TARGET_CHAINFILE=${DATA}/${ORG}-ca-chain.pem
# Wait for the root CA to start
waitPort "root CA to start" 60 $ROOT_CA_LOGFILE $ROOT_CA_HOST 7054

# Initialize the intermediate CA
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-server/fabric-ca-server init -b $BOOTSTRAP_USER_PASS -u $PARENT_URL

# Copy the intermediate CA's certificate chain to the data directory to be used by others
cp $FABRIC_CA_SERVER_HOME/ca-chain.pem $TARGET_CHAINFILE

# Add the custom orgs
for o in $FABRIC_ORGS; do
   aff=$aff"\n   $o: []"
done
aff="${aff#\\n   }"
sed -i "/affiliations:/a \\   $aff" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
sed -i "s/OU: Fabric/OU: COP/g" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# Start the intermediate CA
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-server/fabric-ca-server start
