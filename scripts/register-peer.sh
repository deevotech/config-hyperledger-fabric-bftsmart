#!/bin/bash
#
# Copyright Deevo Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script does the following:
# 1) registers orderer and peer identities with intermediate fabric-ca-servers
# 2) Builds the channel artifacts (e.g. genesis block, etc)
#
usage() {
	echo "Usage: $0 [-g <orgname>]" 1>&2
	exit 1
}
while getopts ":g:" o; do
	case "${o}" in
	g)
		g=${OPTARG}
		;;
	*)
		usage
		;;
	esac
done
shift $((OPTIND - 1))
if [ -z "${g}" ]; then
	usage
fi
source $(dirname "$0")/env.sh
ORG=${g}

function main() {
	mkdir -p ${DATA}
	log "Beginning building channel artifacts ..."
	registerIdentities
	getCACerts
	log "Finished building channel artifacts"
}

# Enroll the CA administrator
function enrollCAAdmin() {
	#waitPort "$CA_NAME to start" 90 $CA_LOGFILE $CA_HOST 7054
	log "Enrolling with $CA_NAME as bootstrap identity ..."
	mkdir -p $HOME/cas
	export FABRIC_CA_CLIENT_HOME=$HOME/cas/$CA_NAME
	export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
	$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
}

function registerIdentities() {
	log "Registering identities ..."
	#registerOrdererIdentities
	registerPeerIdentities
}

# Register any identities associated with a peer
function registerPeerIdentities() {
	#for ORG in $PEER_ORGS; do
	initOrgVars $ORG
	enrollCAAdmin
	local COUNT=1
	while [[ "$COUNT" -le $NUM_PEERS ]]; do
		initPeerVars $ORG $COUNT
		log "Registering $PEER_NAME with $CA_NAME"
		$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer
		COUNT=$((COUNT + 1))
	done
	log "Registering admin identity with $CA_NAME"
	# The admin identity has the "admin" attribute which is added to ECert by default
	$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert,chaincode_example02.init=true:ecert,marbles02.init=true:ecert,supplychain.init=true:ecert"
	log "Registering user identity with $CA_NAME"
	$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS
	#done
}

function getCACerts() {
	log "Getting CA certificates ..."
	#for ORG in $ORGS; do
	initOrgVars $ORG
	log "Getting CA certs for organization $ORG and storing in $ORG_MSP_DIR"
	export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
	$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $ORG_MSP_DIR
	finishMSPSetup $ORG_MSP_DIR
	# If ADMINCERTS is true, we need to enroll the admin now to populate the admincerts directory
	if [ $ADMINCERTS ]; then
		switchToAdminIdentity
	fi
	#done
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main
