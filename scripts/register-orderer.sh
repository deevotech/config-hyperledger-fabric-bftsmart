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

ORG=${g}

function main() {
	mkdir -p ${DATA}
	log "Beginning building channel artifacts ..."
	registerIdentities
	getCACerts
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
	registerOrdererIdentities
}

# Register any identities associated with the orderer
function registerOrdererIdentities() {
	#for ORG in $ORDERER_ORGS; do
	initOrgVars $ORG
	enrollCAAdmin
	local COUNT=1
	while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
		initOrdererVars $ORG $COUNT
		log "Registering $ORDERER_NAME with $CA_NAME"
		$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
		COUNT=$((COUNT + 1))
	done
	log "Registering admin identity with $CA_NAME"
	# The admin identity has the "admin" attribute which is added to ECert by default
	$GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client/fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
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

function generateChannelArtifacts() {

	#which configtxgen
	if [ "$?" -ne 0 ]; then
		fatal "configtxgen tool not found. exiting"
	fi

	log "Generating orderer genesis block at $GENESIS_BLOCK_FILE"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	#cp /data/core.yaml $FABRIC_CFG_PATH/
	$GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPBFTsmart -outputBlock $GENESIS_BLOCK_FILE
	if [ "$?" -ne 0 ]; then
		fatal "Failed to generate orderer genesis block"
	fi

	log "Generating channel configuration transaction at $CHANNEL_TX_FILE"
	$GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
	if [ "$?" -ne 0 ]; then
		fatal "Failed to generate channel configuration transaction"
	fi

	for ORG in $PEER_ORGS; do
		initOrgVars $ORG
		log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
		$GOPATH/src/github.com/hyperledger/fabric/build/bin/configtxgen -profile SampleSingleMSPChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
			-channelID $CHANNEL_NAME -asOrg $ORG
		if [ "$?" -ne 0 ]; then
			fatal "Failed to generate anchor peer update for $ORG"
		fi
	done

}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main
