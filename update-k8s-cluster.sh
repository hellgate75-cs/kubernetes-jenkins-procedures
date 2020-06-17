#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
# '${params.Environment}' '${params.Instance}' '${params.Namespace}'
# '${params.MongoIP}' '${params.MongoPort}'
# '${params.StackRepo}' '${params.StackVersion}' '${params.Group}'
#'${params.Service}' '${params.Repository}' '${params.Version}''${params.Mock}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
INSTANCE="$3"
CHART_TYPE="$4"
STACK_TYPE="$4"
SERVICE="$5"
SERVICE_REPO="$6"
SERVICE_VER="$7"
FORCE_UPDATE="$8"
DATA_REFERENCE="$9"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	exit 1
fi

if [ "" = "$NODE_NAME" ]; then
	echo "Environment Host is mandatory at args position 2"
	exit 1
fi

if [ "" = "$INSTANCE" ]; then
	echo "Instance name is mandatory at args position 3"
	exit 1
fi

if [ "" = "$CHART_TYPE" ]; then
	echo "Application type is mandatory at args position 4"
	exit 1
fi

if [ "" = "$SERVICE" ]; then
	echo "Service name is mandatory at args position 5"
	exit 1
fi

if [ "" = "$SERVICE_REPO" ]; then
	echo "Service Repository is mandatory at args position 6"
	exit 1
fi

if [ "" = "$SERVICE_VER" ]; then
	echo "Service Version is mandatory at args position 7"
	exit 1
fi

if [ "true" != "$FORCE_UPDATE" ]; then
	FORCE_UPDATE="false"
fi

if [ "" != "$(echo $CHART_TYPE|grep mongo)" ]; then
	# mongo stack case
	echo "Setting up MongoDb Stack ..."
	CHART_TYPE="$(echo $CHART_TYPE|awk 'BEGIN {FS=OFS="-mongo"}{print $1}')"
	STACK_TYPE="${CHART_TYPE}-db"
	echo "MongoDb Stack: Data Reference: $DATA_REFERENCE"
	if [ "" != "$DATA_REFERENCE" ]; then
		REFERENCE="s3://cs-aws-backup-jenkins/mongodb/${DATA_REFERENCE}.archive"
		DATA_REFERENCE="$REFERENCE"
	fi
fi

MOCKED_DATA="false"

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
echo "Cluster Host name: $NODE_NAME"
echo "Instance name: $INSTANCE"
echo "Chart Group: $CHART_TYPE"
echo "Stack Group: $STACK_TYPE"
echo "Service name: $SERVICE"
echo "Service repository: $SERVICE_REPO"
echo "Service version: $SERVICE_VER"
echo "Use Helm Replacement Strategy : $FORCE_UPDATE"
echo "Use Moked Data: $MOCKED_DATA"
echo ""
echo ""
NODE_HOST="$(k8s-cli -command details -subject node -cluster-name $ENV -node-name $NODE_NAME | jq -r '.hostname')"

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "Unable to recover hostname for cluster: $ENV for node: $NODE_NAME"
	echo "Abort!!"
	exit 1
fi

PREPARATION_ENV="$(k8s-cli -command prepare -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE | jq -r .content | grep -v null)"
if [ "" = "$PREPARATION_ENV" ]; then
	echo "Instance $INSTANCE not prepared for errors"
	echo "Abort!!"
	exit 1
fi
echo "Env file path: $PREPARATION_ENV ..."
source $PREPARATION_ENV 2>/dev/null
eval "$(cat $PREPARATION_ENV 2>/dev/null)"

if [ "" = "$CLUSTER_INDEX" ] || [ "number" != "$(variableType $CLUSTER_INDEX)" ]; then
	echo "Couldn't recover cluster index for instance $INSTANCE..."
	echo "Abort!!"
	exit 1
fi
HOME_PATH="$(realpath ~/)"
mkdir -p ${HOME_PATH}/.k8s-cli/clusters/$ENV/$NAMESPACE
CREATION_INFRA_FILE="${HOME_PATH}/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-values.yaml"
echo "Service Creation K8s stack values file: $CREATION_INFRA_FILE"
INFRA_CREATION_VALUES_FILE="$CREATION_INFRA_FILE"
if [ "" = "$INFRA_CREATION_VALUES_FILE" ]; then
	echo "File: $CREATION_INFRA_FILE doesn't exist on the k8s-cli database!!"
	echo "Please verify creation of stack was successful!!"
	echo "Abort!"
	exit 1
fi
MONGO_DB_IP=""
MONGO_DB_PORT=""
if [ -e $INFRA_CREATION_VALUES_FILE ]; then
	echo "Recovering MongoDb Ip and port from creation configuration at : $INFRA_CREATION_VALUES_FILE ..."
	MONGO_DB_IP="$(cat $INFRA_CREATION_VALUES_FILE | yq r - 'services.mongoDbIp')"
	MONGO_DB_PORT="$(cat $INFRA_CREATION_VALUES_FILE | yq r - 'services.mongoDbPort')"
	echo "MONGO_DB_IP: $MONGO_DB_IP"
	echo "MONGO_DB_PORT: $MONGO_DB_PORT"
else
	echo "Unable to find creation values file: $INFRA_CREATION_VALUES_FILE"
	echo "Please verify creation of stack was successful!!"
	echo "Abort!"
	exit 1
fi

if [ "" = "$MONGO_DB_IP" ] || [ "" = "$MONGO_DB_PORT" ]; then
	echo "Unable to recover Mongo Db IP and Or Port from file: $INFRA_CREATION_VALUES_FILE"
	echo "Abort!"
	exit 1
fi

echo " "
echo " "
echo "Using service data:"
echo "==================="
echo "Mongo Db Ip address: $MONGO_DB_IP"
echo "Mongo Db Port: $MONGO_DB_PORT"
echo " "
echo " "
NEW_UPDATE_VALUES_FILE="${HOME_PATH}/.k8s-cli/clusters/$ENV/$NAMESPACE/$ENV-$INSTANCE-$STACK_TYPE-global-update-values-$(date +%F-%T-%N).yaml"

cp $CD_PATH/config/$STACK_TYPE-update-values-node-$CLUSTER_INDEX.yaml $NEW_UPDATE_VALUES_FILE

cd $CD_PATH/kubernetes-$STACK_TYPE-charts

echo "Replace affinity node with installation node: <${NODE_HOST}>"
sed -e "s/AFFINITY_NODE_HOSTNAME/${NODE_HOST}/g" -i $NEW_UPDATE_VALUES_FILE

echo "Verifing BRANCH and VERSION assignment for given custom service: $SERVICE ..."
SERVICE_TEMPLATE="$(translateServiceToTemplate "$SERVICE")"
if [ ":" != "$SERVICE_TEMPLATE" ]; then
	echo "Replacing docker image branch/version for custom service: $SERVICE"
	SVC_TMPL_BRANCH="$(echo "$SERVICE_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $1}')"
	if [ "x" != "x$SVC_TMPL_BRANCH" ]; then
		echo "For custom service: $SVC_TMPL_BRANCH -> $SERVICE_REPO"
		sed -e "s/${SVC_TMPL_BRANCH}/$SERVICE_REPO/g" -i $NEW_UPDATE_VALUES_FILE
	fi
	SVC_TMPL_VERSION="$(echo "$SERVICE_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $2}')"
	if [ "x" != "x$SVC_TMPL_VERSION" ]; then
		echo "For custom service: $SVC_TMPL_VERSION -> $SERVICE_VER"
		sed -e "s/${SVC_TMPL_VERSION}/$SERVICE_VER/g" -i $NEW_UPDATE_VALUES_FILE
	fi
	SVC_TMPL_ENABLED="$(echo "$SERVICE_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $3}')"
	if [ "x" != "x$SVC_TMPL_ENABLED" ]; then
		echo "For custom service: $SVC_TMPL_ENABLED -> true"
		sed -e "s/${SVC_TMPL_ENABLED}/true/g" -i $NEW_UPDATE_VALUES_FILE
	fi
else
	echo "Custom Service: $SERVICE has not template for BRANCH and VERSION"
	echo "Abort!!"
	exit 1
fi

IFS=$'\n';for svc in $(getServiceList); do
	DEF_SVC_TEMPLATE="$(translateServiceToTemplate "$svc")"
	if [ ":" != "$DEF_SVC_TEMPLATE" ]; then
		echo "Replacing docker image branch/version for service: $svc"
		DEF_SVC_TMPL_BRANCH="$(echo "$DEF_SVC_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $1}')"
		if [ "x" != "x$DEF_SVC_TMPL_BRANCH" ]; then
			echo "For service: $DEF_SVC_TMPL_BRANCH -> $SERVICE_REPO"
			sed -e "s/${DEF_SVC_TMPL_BRANCH}/$SERVICE_REPO/g" -i $NEW_UPDATE_VALUES_FILE
		fi
		DEF_SVC_TMPL_VERSION="$(echo "$DEF_SVC_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $2}')"
		if [ "x" != "x$DEF_SVC_TMPL_BRANCH" ]; then
			echo "For service: $DEF_SVC_TMPL_VERSION -> $SERVICE_VER"
			sed -e "s/${DEF_SVC_TMPL_VERSION}/$SERVICE_VER/g" -i $NEW_UPDATE_VALUES_FILE
		fi
		DEF_TMPL_ENABLED="$(echo "$DEF_SVC_TEMPLATE"|awk 'BEGIN {FS=OFS=":"}{print $3}')"
		if [ "x" != "x$DEF_TMPL_ENABLED" ]; then
			echo "For service: $DEF_TMPL_ENABLED -> false"
			sed -e "s/${DEF_TMPL_ENABLED}/false/g" -i $NEW_UPDATE_VALUES_FILE
		fi
	else
		echo "Service: $svc has not template for BRANCH and VERSION"
	fi
done

echo "Setting Install Mocked data to : $MOCKED_DATA ..."
sed -e "s/MOCKED_DATA/$MOCKED_DATA/g" -i $NEW_UPDATE_VALUES_FILE

echo "Assigning Mongo-Db Hostname/IPAddress and Port..."
sed -e "s/MONGO_DB_IP/$MONGO_DB_IP/g" -i $NEW_UPDATE_VALUES_FILE
sed -e "s/MONGO_DB_PORT/$MONGO_DB_PORT/g" -i $NEW_UPDATE_VALUES_FILE

echo "File $NEW_UPDATE_VALUES_FILE is ready for update ..."

cd $CD_PATH/kubernetes-$CHART_TYPE-charts
echo "Updating stack $STACK_TYPE on namespace: $NAMESPACE ..."
SCRIPT_FILE="$CD_PATH/kubernetes-$CHART_TYPE-charts/run-backend-services-upgrade.sh"
if [ -e $SCRIPT_FILE ]; then
	eval "kubectl $KUBECTL_BASE get namespace $NAMESPACE 2> /dev/null"
	bash -c "$SCRIPT_FILE $PREPARATION_ENV $NEW_UPDATE_VALUES_FILE $STACK_TYPE $HOSTNAME $FORCE_UPDATE $DATA_REFERENCE"
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
if [ -e $NEW_UPDATE_VALUES_FILE ]; then
	rm $NEW_UPDATE_VALUES_FILE
fi
exit 0


