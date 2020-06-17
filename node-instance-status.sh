#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"

if [ "" = "$ENV" ]; then
	echo "ERROR: Environment"
	exit 1
fi

if [ "" = "$NODE_NAME" ]; then
	echo "ERROR: Empty Node Name"
	exit 1
fi

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "ERROR: HostName (Cluster: $ENV, Node: $NODE_NAME)"
	exit 1
fi

STATE="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].State.Name' --output text|grep -v None)"
echo "$STATE"
exit 0
