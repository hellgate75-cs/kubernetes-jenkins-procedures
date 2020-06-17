#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
ACTION="$3"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$NODE_NAME" ]; then
	echo "Node of cluster $ENV, Node: $NODE_NAME was not found!!"
	echo "Abort!"
	exit 1
fi

if [ "" = "$ACTION" ]; then
	echo "Empty Action, for Node: $NODE_NAME is unknown!!"
	echo "Abort!"
	exit 1
fi

if [ "start" != "$ACTION" ] && [ "stop" != "$ACTION" ] && [ "status" != "$ACTION" ]; then
	echo "Action $ACTION, for Node: $NODE_NAME is unknown!!"
	echo "Abort!"
	exit 1
fi

echo "Summary: "
echo "========="
echo " "
echo "Cluster name: $ENV"
echo "Node name: $NODE_NAME"
echo "Action: $ACTION"
echo " "
echo " "

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "Unable to recover hostname for cluster: $ENV for node: $NODE_NAME"
	echo "Abort!!"
	exit 1
fi

echo "Hostname: $HOSTNAME"

STATE="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].State.Name' --output text|grep -v None)"
INSTANCE_ID="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].InstanceId' --output text|grep -v None)"

echo " "
echo " "
echo "-----------------"
echo "Node: $NODE_NAME"
echo "Host: $HOSTNAME"
echo "Node: $NODE_NAME_ID"
echo "State: $STATE"
if [ "running" = "$STATE" ]; then
	PUBLIC_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp' --output text|grep -v None)"
	PRIVATE_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddress' --output text|grep -v None)"
	echo "Public Ip: $PUBLIC_IP"
	echo "Private Ip: $PRIVATE_IP"
else
	echo "No IP ADDRESS informtion available"
fi
echo "-----------------"
echo " "
echo " "
if [ "" = "$INSTANCE_ID" ]; then
	echo "Unknown instance id, cannot continue ..."
	echo "Please contact system administrators!!"
	echo "Abort!!"
	exit 1
fi
if [ "start" = "$ACTION" ]; then
	echo "Starting node: $NODE_NAME, with host: $HOSTNAME ..."
	if [ "running" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is already running ..."
	elif [ "pending" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is pending some operation, no changes until operation finish ..."
	elif [ "stopped" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME starting node ..."
		aws ec2 start-instances --instance-ids "$INSTANCE_ID"
		echo "Cluster $ENV, Node $NODE_NAME command applied!!"
		STATE="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].State.Name' --output text|grep -v None)"
		echo "Cluster $ENV, Node $NODE_NAME new state: $STATE"
	else
		echo "Cluster $ENV, Node $NODE_NAME unknown state, please contact system administrators ..."
		echo "Abort!!"
		exit 1
	fi
elif [ "stop" = "$ACTION" ]; then
	echo "stopping node: $NODE_NAME, with host: $HOSTNAME ..."
	if [ "running" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME stopping node ..."
		aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
		echo "Cluster $ENV, Node $NODE_NAME command applied!!"
		STATE="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].State.Name' --output text|grep -v None)"
		echo "Cluster $ENV, Node $NODE_NAME new state: $STATE"
	elif [ "pending" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is pending some operation, no changes until operation finish ..."
	elif [ "stopped" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is already stopped ..."
	else
		echo "Cluster $ENV, Node $NODE_NAME unknown state, please contact system administrators ..."
		echo "Abort!!"
		exit 1
	fi
elif [ "status" = "$ACTION" ]; then
	echo "Verifying node: $NODE_NAME, with host: $HOSTNAME ..."
	if [ "running" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is RUNNING!!"
	elif [ "stopped" = "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is STOPPED!!"
	elif [ "" != "$STATE" ]; then
		echo "Cluster $ENV, Node $NODE_NAME is $STATE!!"
	else
		echo "Cluster $ENV, Node $NODE_NAME is unknown state!!"
	fi
fi
echo "Success!!"
exit 0
