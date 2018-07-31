#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
usage() { echo "Usage: $0 [-g <orgname>] [-r <restart>]" 1>&2; exit 1; }
while getopts ":g:r:" o; do
    case "${o}" in
        g)
            g=${OPTARG}
            ;;
        r)
            r=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "${g}" ] || [ -z "${r}" ] ; then
    usage
fi
source $(dirname "$0")/env.sh
set -e
export FABRIC_CA_SERVER_HOME=$HOME/fabric-ca
export FABRIC_CA_SERVER_TLS_ENABLED=true
export FABRIC_CA_SERVER_CSR_CN=rca-${g}
export FABRIC_CA_SERVER_CSR_HOSTS=rca-${g}
export FABRIC_CA_SERVER_DEBUG=true
export BOOTSTRAP_USER_PASS=rca-${g}-admin:rca-${g}-adminpw
export TARGET_CERTFILE=$DATA/${g}-ca-cert.pem
rm -rf $HOME/fabric-ca/*
# Initialize the root CA
if [ ${r} -eq 1 ] ; then
	rm -rf ${FABRIC_CA_SERVER_HOME}/*
	cp -R ${DATA}/rca-${g}-home/* ${FABRIC_CA_SERVER_HOME}/
else 
	$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-server/fabric-ca-server init -b $BOOTSTRAP_USER_PASS
	# Copy the root CA's signing certificate to the data directory to be used by others
	mkdir -p ${DATA}
	rm -rf ${DATA}/*
	cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $TARGET_CERTFILE
	
	# Add the custom orgs
	for o in $FABRIC_ORGS; do
	   aff=$aff"\n   $o: []"
	done
	aff="${aff#\\n   }"
	sed -i "/affiliations:/a \\   $aff" \
	   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
	sed -i "s/OU: Fabric/OU: COP/g" \
	   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
fi

# Start the root CA
mkdir -p data
mkdir -p data/logs
$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-server/fabric-ca-server start > ./data/logs/fabric-ca-rca-${g}.out 2>&1 &
