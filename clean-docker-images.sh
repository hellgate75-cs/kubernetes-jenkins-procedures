#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
KEYFILE="$3"
TYPE="$4"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$KEYFILE" ]; then
	echo "Key file is mandatory at args position 3"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$TYPE" ]; then
	echo "Clean type is mandatory at args position 2"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$NODE_NAME" ] || [ "NO_NODE" == "$NODE_NAME" ]; then
	NODES="$( k8s-cli -command show -subject nodes  -cluster-name $ENV | jq -r .content[].name 2> /dev/null|grep -v null)"
	if [ "" = "$NODES" ]; then
		echo "Cannot recover nodes for cluster: $ENV"
		echo "Abort!"
		exit 1
	fi
	NODE_NAME=""
	IFS=$'\n';for nd in $NODES; do
		if [ "" = "$NODE_NAME" ]; then
			INSTS="$(k8s-cli -command show -subject instances -cluster-name $ENV -node-name $nd 2> /dev/null|jq -r .content[].name|grep -v null)"
			if [ "" != "$INSTS" ]; then
				IFS=$'\n';for is in $INSTS; do
					if [ "$is" = "$INSTANCE" ]; then
						NODE_NAME="$nd"
					fi
				done
			fi
		fi
	done
fi

if [ "" = "$NODE_NAME" ]; then
	echo "Node of cluster $ENV, Instance: $INSTANCE was not found!!"
	echo "Abort!"
	exit 1
fi

echo "Summary: "
echo "========="
echo " "
echo "Cluster name: $ENV"
echo "Node name: $NODE_NAME"
echo "Key file: $CD_PATH/$KEYFILE"
echo "Clean type: $TYPE"

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "Unable to recover hostname for cluster: $ENV for node: $NODE_NAME"
	echo "Abort!!"
	exit 1
fi

echo "Hostname: $HOSTNAME"

PUBLIC_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp' --output text|grep -v None)"

if [ "" = "$PUBLIC_IP" ]; then
	echo "Unable to recover public ip for cluster: $ENV in node: $NODE_NAME for hostname: $HOSTNAME"
	echo "Abort!!"
	exit 1
fi
echo "Public Ip: $PUBLIC_IP"

if [ "ALL" == "$TYPE" ]; then
	IMAGELINES="$(ssh -o StrictHostKeyChecking=no -q -i $CD_PATH/$KEYFILE docker@$PUBLIC_IP "docker image ls 2> /dev/null|grep -v REPOSITORY")"
	if [ "" != "$IMAGELINES" ]; then
		echo "Cleaning all docker images at the host: $HOSTNAME"
		IMAGES="$(echo \"$IMAGELINES\"|awk 'BEGIN {FS=OFS=" "}{print $3}'|xargs echo)"
		
		if [ "" != "$IMAGES" ]; then
			echo "Images that will be removed: $IMAGES"
			ssh -o StrictHostKeyChecking=no -q -i $CD_PATH/$KEYFILE docker@$PUBLIC_IP "docker rmi -f $IMAGES"
		else
			echo "No images found ..."
		fi
	else
		echo "No docker image present ..."
	fi
else
	IMAGELINES="$(ssh -o StrictHostKeyChecking=no -q -i $CD_PATH/$KEYFILE docker@$PUBLIC_IP "docker image ls 2> /dev/null|grep '$TYPE'")"
	if [ "" != "$IMAGELINES" ]; then
		echo "Cleaning '$TYPE' docker images types at the host: $HOSTNAME"
		IMAGES="$(echo \"$IMAGELINES\"|awk 'BEGIN {FS=OFS=" "}{print $3}'|xargs echo)"
		if [ "" != "$IMAGES" ]; then
			echo "Images that will be removed: $IMAGES"
			ssh -o StrictHostKeyChecking=no -q -i $CD_PATH/$KEYFILE docker@$PUBLIC_IP "docker rmi -f $IMAGES"
		else
			echo "No images found ..."
		fi
	else
		echo "No docker image present matching with: $TYPE ..."
	fi
fi
echo "Success!!"
exit 0
