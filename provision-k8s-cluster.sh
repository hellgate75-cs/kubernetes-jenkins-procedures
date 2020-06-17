#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
# '${params.Environment}' '${params.Instance}' '${params.Namespace}'
# '${params.MongoIP}' '${params.MongoPort}'
# '${params.StackRepo}' '${params.StackVersion}' '${params.Group}'
#'${params.Service}' '${params.Repository}' '${params.Version}''${params.Mock}'

source $CD_PATH/addson.sh

ENV="$1"
INSTANCE="$2"
NAMESPACE="$3"
MONGO_IP="$4"
MONGO_PORT="$5"
STACK_REPO="$6"
STACK_VERS="$7"
CHART_TYPE="$8"
STACK_TYPE="$8"
MOCKED_DATA="$9"
ENABLE_JEAGER="${10}"
CERTFILE="${11}"
DATA_REFERENCE="${12}"

echo "Parameters: [$@]"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	exit 1
fi

if [ "" = "$INSTANCE" ]; then
	echo "Instance name is mandatory at args position 2"
	exit 1
fi

if [ "" = "$NAMESPACE" ]; then
	echo "Namespace name is mandatory at args position 3"
	exit 1
fi

if [ "" = "$MONGO_IP" ]; then
	echo "MongoDb Ip Address is mandatory at args position 4"
	exit 1
fi

if [ "" = "$MONGO_PORT" ]; then
	echo "MongoDb Port is mandatory at args position 5"
	exit 1
fi

if [ "" = "$STACK_REPO" ]; then
	echo "Stack Repository is mandatory at args position 6"
	exit 1
fi

if [ "" = "$STACK_VERS" ]; then
	echo "Stack Version is mandatory at args position 7"
	exit 1
fi

if [ "" = "$CHART_TYPE" ]; then
	echo "Application type is mandatory at args position 8"
	exit 1
fi

if [ "" = "$MOCKED_DATA" ]; then
	echo "Mocked Data is optional at args position 9"
	echo "By default the value will be swt to false"
	MOCKED_DATA="false"
fi

if [ "" = "$ENABLE_JEAGER" ]; then
	echo "Enable Jaeger is optional at args position 10"
	echo "Available values are [true/false], by default the value will be set to false"
	ENABLE_JEAGER="false"
fi

if [ "true" != "$ENABLE_JEAGER" ] && [ "false" != "$ENABLE_JEAGER" ]; then
	echo "Unknown Enable Jaeger value: $ENABLE_JEAGER"
	echo "Available values are [true/false], by default the value will be set to false"
	ENABLE_JEAGER="false"
fi

if [ "true" != "$MOCKED_DATA" ] && [ "false" != "$MOCKED_DATA" ]; then
	echo "Mocked Data is optional at args position 9"
	echo "Available values are [true/false], by default the value will be set to false"
	MOCKED_DATA="false"
fi

if [ "" != "$(echo $CHART_TYPE|grep mongo)" ]; then
	# mongo stack case
	echo "Setting up MongoDb Stack ..."
	CHART_TYPE="$(echo $CHART_TYPE|awk 'BEGIN {FS=OFS="-mongo"}{print $1}')"
	STACK_TYPE="${CHART_TYPE}-db"
	echo "MongoDb Stack: Data Reference: $DATA_REFERENCE"
#	if [ "" = "$DATA_REFERENCE" ]; then
#		if [ "true" != "$MOCKED_DATA" ]; then
#			echo "Missing archive data file reference ..."
#			echo "Abort!"
#			exit 1
#		fi
#	else
	if [ "" != "$DATA_REFERENCE" ]; then
		REFERENCE="s3://cs-aws-backup-jenkins/mongodb/${DATA_REFERENCE}.archive"
		DATA_REFERENCE="$REFERENCE"
	fi
else
	DATA_REFERENCE="NO_DATA"
fi

if [ "x" = "x$DATA_REFERENCE" ]; then
	DATA_REFERENCE="NO_DATA"
fi

# Initialize Charts Repository for group
if [ ! -e $CD_PATH/kubernetes-$CHART_TYPE-charts ]; then
	$CD_PATH/init-charts.sh "$CHART_TYPE"
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
echo "Instance name: $INSTANCE"
echo "NameSpace name: $NAMESPACE"
echo "Mongo Db Ip address: $MONGO_IP"
echo "Mongo Db Port: $MONGO_PORT"
echo "Stack Repository: $STACK_REPO"
echo "Stack Version: $STACK_VERS"
echo "Chart Type: $CHART_TYPE"
echo "Stack Type: $STACK_TYPE"
if [ "" = "$DATA_REFERENCE" ]; then
	echo "Use Moked Data: $MOCKED_DATA"
else
	echo "Use Archive Data: $MOCKED_DATA"
	echo "Data archive position: $DATA_REFERENCE"
fi
if [ "" = "$CERTFILE" ]; then
	echo "SSH Certificate/Key is mandatory at args position 5: setting default value: certs/mambas-generic.pem"
	CERTFILE="certs/mambas-generic.pem"
fi
echo "SSH Certificate path: $CERTFILE"
echo "Enable Jaeger: $ENABLE_JEAGER"

echo ""
echo ""
NODE_NAME="$(k8s-cli -command ensure -subject instance  -cluster-name $ENV 2> /dev/null| jq -r .nodeName|grep -v null)"
AVAILABLE="$(k8s-cli -command ensure -subject instance  -cluster-name $ENV 2> /dev/null| jq -r .available|grep -v null)"
if [ "" = "$AVAILABLE" ]; then
	AVAILABLE="false"
fi
if [ "false" = "$AVAILABLE" ]; then
	echo "No nodes available for cluster: $ENV"
	echo "Abort!!"
	exit 1
fi
echo "Free Node: $NODE_NAME"

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "Unable to recover hostname for cluster: $ENV for node: $NODE_NAME"
	echo "Abort!!"
	exit 1
fi

echo "Hostname: $HOSTNAME"

CREATE_STATUS="$(k8s-cli -command add -subject instance  -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE --namespace $NAMESPACE 2> /dev/null|jq -r .status|grep -v null)"
if [ "Created" != "$CREATE_STATUS" ] && [ "created" != "$CREATE_STATUS" ]; then
	echo "Cluster Node Instance not created"
	echo "Abort!!"
	exit 1
fi
PREPARATION_ENV="$(k8s-cli -command prepare -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE | jq -r .content | grep -v null)"
if [ "" = "$PREPARATION_ENV" ]; then
	echo "Instance $INSTANCE not prepared for errors"
	echo "Abort!!"
	exit 1
fi
echo "Environment file: $PREPARATION_ENV"
source $PREPARATION_ENV 2>/dev/null
eval "$(cat $PREPARATION_ENV 2>/dev/null)"

if [ "" = "$CLUSTER_INDEX" ] || [ "number" != "$(variableType $CLUSTER_INDEX)" ]; then
	echo "Couldn't recover cluster index for instance $INSTANCE..."
	echo "Abort!!"
	exit 1
fi

mkdir -p ~/.k8s-cli/clusters/$ENV/$NAMESPACE

cp $CD_PATH/config/$STACK_TYPE-values-node-$CLUSTER_INDEX.yaml ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml

cd $CD_PATH/kubernetes-$CHART_TYPE-charts

PUBLIC_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp' --output text|grep -v None)"

echo "Replace affinity node with installation node: <${NODE_HOST}>"
sed -e "s/AFFINITY_NODE_HOSTNAME/${NODE_HOST}/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml

echo "Setting Install Mocked data to : $MOCKED_DATA ..."
sed -e "s/MOCKED_DATA/$MOCKED_DATA/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml

echo "Setting Install Deploy Jaeger to : $ENABLE_JEAGER ..."
sed -e "s/ENABLE_JEAGER/$ENABLE_JEAGER/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml

IFS=$'\n';for svc in $(getServiceList); do
	DEF_SVC_TEMPLATE="$(translateServiceToTemplate "$svc")"
	if [ ":" != "$DEF_SVC_TEMPLATE" ]; then
		echo "Replacing docker image branch/version for service: $svc"
		DEF_SVC_TMPL_BRANCH="$(echo "$DEF_SVC_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $1}')"
		if [ "x" != "x$DEF_SVC_TMPL_BRANCH" ]; then
			echo "For service: $DEF_SVC_TMPL_BRANCH -> $STACK_REPO"
			sed -e "s/${DEF_SVC_TMPL_BRANCH}/$STACK_REPO/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml
		fi
		DEF_SVC_TMPL_VERSION="$(echo "$DEF_SVC_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $2}')"
		if [ "x" != "x$DEF_SVC_TMPL_BRANCH" ]; then
			echo "For service: $DEF_SVC_TMPL_VERSION -> $STACK_VERS"
			sed -e "s/${DEF_SVC_TMPL_VERSION}/$STACK_VERS/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml
		fi
	else
		echo "Service: $svc has not template for BRANCH and VERSION"
	fi
done

echo "Assigning Mongo-Db Hostname/IPAddress and Port..."
sed -e "s/MONGO_DB_IP/$MONGO_IP/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml
sed -e "s/MONGO_DB_PORT/$MONGO_PORT/g" -i ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml

SCRIPT_FILE="$CD_PATH/kubernetes-$CHART_TYPE-charts/run-sequence-manually.sh"
if [ -e $SCRIPT_FILE ]; then
	echo "Current deploy configuration:"
	cat ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml
	echo " "
	echo " "
	eval "kubectl $KUBECTL_BASE create namespace $NAMESPACE 2> /dev/null"
	if [ "" != "$PUBLIC_IP" ]; then
		ssh -i $CD_PATH/$CERTFILE docker@${PUBLIC_IP} sudo mkdir -p /mnt/sda/${CHART_TYPE}/${NAMESPACE}
	else
		echo "Unable to recover public ip for host: $HOSTNAME"
	fi
	cd $CD_PATH/kubernetes-$CHART_TYPE-charts
	bash -c "$SCRIPT_FILE  $PREPARATION_ENV ~/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml $STACK_TYPE $HOSTNAME $DATA_REFERENCE $CD_PATH/$CERTFILE \"docker@${PUBLIC_IP}\" $ENABLE_JEAGER"
	RES="$?"
	if [ "0" != "$RES" ]; then
		echo "Errors during Cluster provisioning: exit code $RES"
		echo "Abort!!"
		exit $RES
	fi
	echo "Success!!"
else
	echo "Script file $SCRIPT_FILE doesn't exist on the filesystem."
	echo "Abort!!"
	exit 1
fi
exit 0


