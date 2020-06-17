#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
# '${params.Environment}' '${params.Instance}' '${params.Namespace}'
# '${params.MongoIP}' '${params.MongoPort}'
# '${params.StackRepo}' '${params.StackVersion}' '${params.Group}'
#'${params.Service}' '${params.Repository}' '${params.Version}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
INSTANCE="$3"
CHART_TYPE="$4"
STACK_TYPE="$4"
CERTFILE="$5"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	exit 1
fi

if [ "" = "$NODE_NAME" ]; then
	echo "Node name is mandatory at args position 2"
	exit 1
fi

if [ "" = "$INSTANCE" ]; then
	echo "Instance name is mandatory at args position 3"
	exit 1
fi

if [ "" = "$CHART_TYPE" ]; then
	echo "Environment type name is mandatory at args position 4"
	exit 1
fi
if [ "" = "$CERTFILE" ]; then
	echo "SSH Certificate/Key is mandatory at args position 5: setting default value: certs/mambas-generic.pem"
	CERTFILE="certs/mambas-generic.pem"
fi

if [ "" != "$(echo $CHART_TYPE|grep mongo)" ]; then
	# mongo stack case
	CHART_TYPE="$(echo $CHART_TYPE|awk 'BEGIN {FS=OFS="-mongo"}{print $1}')"
	STACK_TYPE="${CHART_TYPE}-db"
fi

if [ ! -e $CD_PATH/kubernetes-$CHART_TYPE-charts ]; then
	echo "Unable to access to Chart Repository: kubernetes-$CHART_TYPE-charts"
	echo "Abort!"
	exit 1
fi

# Installing Go! Language
#if [ "" = "$(which go 2>/dev/null)" ]; then
#	$FOLDER/install-golang.sh
#fi


# Install k8s-cli tool
#if [ "" = "$(which k8s-cli 2>/dev/null)" ]; then
#	$FOLDER/install-k8s-cli.sh
#fi

echo "Summary: "
echo "========="
echo " "
echo "Cluster name: $ENV"
echo "Cluster node: $NODE_NAME"
echo "Instance name: $INSTANCE"
echo "Chrt Type: $CHART_TYPE"
echo "Stack Type: $CHART_TYPE"
echo "SSH Certificate/Key file: $PEMFILE"
echo ""
echo ""

PREPARATION_ENV="$(k8s-cli -command prepare -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE | jq -r .content | grep -v null)"
if [ "" = "$PREPARATION_ENV" ]; then
	echo "Instance $INSTANCE not prepared for errors"
	echo "Abort!!"
	exit 1
fi
echo "Env file path: $PREPARATION_ENV ..."
eval "$(cat $PREPARATION_ENV 2>/dev/null)"

if [ "" = "$CLUSTER_INDEX" ] || [ "number" != "$(variableType $CLUSTER_INDEX)" ]; then
	echo "Couldn't recover cluster index for instance $INSTANCE..."
	echo "Abort!!"
	exit 1
fi

cd $CD_PATH/kubernetes-$CHART_TYPE-charts

bash -c "$CD_PATH/kubernetes-$CHART_TYPE-charts/purge-helm-releases.sh $PREPARATION_ENV"
RES="$?"
if [ "0" != "$RES" ]; then
	echo "Errors during Cluster destroy: exit code $RES"
	echo "Abort!!"
	exit $RES
fi

echo "Delete residual components ..."
eval "kubectl $KUBECTL_BASE get all 2> /dev/null | grep -v NAME|awk 'BEGIN {FS=OFS=\" \"}{print $1}'| xargs kubectl $KUBECTL_BASE delete"

echo "Delete residual ingress ..."
eval "kubectl $KUBECTL_BASE get ingress 2> /dev/null | grep -v NAME|awk 'BEGIN {FS=OFS=\" \"}{print $1}'| xargs kubectl $KUBECTL_BASE delete ingress"

echo "Delete all namespace: $NAMESPACE ..."
eval "kubectl $KUBECTL_BASE delete namespace $NAMESPACE 2> /dev/null"

echo -e "Removed in Cluster $ENV following Instance:\n$(k8s-cli -command details -subject instance  -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE -format yaml)"

NAMESPACE="$(k8s-cli -command details -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE | jq -r .namespace)"
if [ "" = "$NAMESPACE" ]; then
	NAMESPACE="$NODE_NAME"
fi

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "Unable to recover hostname for cluster: $ENV for node: $NODE_NAME"
else

	echo "Hostname: $HOSTNAME"

	PUBLIC_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp' --output text|grep -v None)"

	if [ "" = "$PUBLIC_IP" ]; then
		echo "Unable to recover public ip for cluster: $ENV in node: $NODE_NAME for hostname: $HOSTNAME"
	else
		if [ -e $CD_PATH/$CERTFILE ]; then
			echo "Removing storage from host: $HOSTNAME all path /mnt/sda/$CHART_TYPE/$NAMESPACE ..."
			#chmod 600 $CD_PATH/keys/CS-Generic-QA/.ssh/*
			ssh -o StrictHostKeyChecking=no -q -i $CD_PATH/$CERTFILE docker@${PUBLIC_IP} sudo rm -Rf /mnt/sda/$CHART_TYPE/$NAMESPACE
		else
			echo "Cannot remove storage from host: $HOSTNAME in path /mnt/sda/$CHART_TYPE/$NAMESPACE ..."
			echo "Cannot stat SSH certificate/key at : $CD_PATH/$CERTFILE"
			echo "Please remove storage manually"
			echo "Run: ssh -i <key/cert> docker@${PUBLIC_IP} sudo rm -Rf /mnt/sda/$CHART_TYPE/$NAMESPACE"
		fi
	fi
fi

echo "Removing Local Instance: $INSTANCE from cluster: $ENV and relevant folder: /root/.k8s-cli/clusters/$ENV/$NAMESPACE"

k8s-cli -command remove -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE -format yaml

rm -Rf ~/.k8s-cli/clusters/$ENV/$NAMESPACE

echo "Success!!"
exit 0


