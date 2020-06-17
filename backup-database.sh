#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
INSTANCE="$3"
TYPE="$4"
BACKUP_PREFIX="$5"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$INSTANCE" ]; then
	echo "Instance name is mandatory at args position 2"
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

if [ "" = "$BACKUP_PREFIX" ]; then
	BACKUP_PREFIX="aangine"
fi

if [ "" = "$NODE_NAME" ]; then
	echo "Node of cluster $ENV, Instance: $INSTANCE was not found!!"
	echo "Abort!"
	exit 1
fi

BACKUP_NAME="${BACKUP_PREFIX}$(date +"%Y%m%d%H%M").archive"

echo "Summary: "
echo "========="
echo " "
echo "Cluster name: $ENV"
echo "Node name: $NODE_NAME"
echo "Instance name: $INSTANCE"
echo "Application Type: $TYPE"
echo "Backup name: $BACKUP_NAME"

PREPARATION_ENV="$(k8s-cli -command prepare -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE | jq -r .content | grep -v null)"
if [ "" = "$PREPARATION_ENV" ]; then
	echo "Instance $INSTANCE not prepared for errors"
	echo "Abort!!"
	exit 1
fi
echo "Source file: $PREPARATION_ENV"

eval "$(cat $PREPARATION_ENV 2>/dev/null)"

if [ "" = "$CLUSTER_INDEX" ] || [ "number" != "$(variableType $CLUSTER_INDEX)" ]; then
	echo "Couldn't recover cluster index for instance $INSTANCE..."
	echo "Abort!!"
	exit 1
fi

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
CMD="kubectl $KUBECTL_BASE get svc 2> /dev/null|grep -v NAME"
BACKUP=0
#Mongo parameters
USERNAME="root"
PASSWORD="aangine1234@"
AUTH_DB="admin"
MONGO_S3_BUCKET_URL="s3://cs-aws-backup-jenkins/mongodb"
IFS=$'\n';for ksvc in $(eval "$CMD"); do
	xsvc="$(echo "$ksvc"|awk 'BEGIN {FS=OFS=" "}{print $1}')"

	if [ "" != "$(echo "$xsvc"|grep -i external|grep -i mongodb)" ]; then
		eval "DB_PORT=\"\$(kubectl $KUBECTL_BASE get svc $xsvc -o jsonpath={.spec.ports[0].port} 2> /dev/null)\""
		echo "Backup running on host: $PUBLIC_IP and port: $DB_PORT ..."
		mongodump --host $PUBLIC_IP --port $DB_PORT --username $USERNAME --password $PASSWORD --authenticationDatabase $AUTH_DB --gzip --archive=$CD_PATH/$BACKUP_NAME
		if [ -e $CD_PATH/$BACKUP_NAME ]; then
			echo "Remove temporary file at: $CD_PATH/$BACKUP_NAME ..."
			aws s3 cp $CD_PATH/$BACKUP_NAME $MONGO_S3_BUCKET_URL/$BACKUP_NAME
			echo "Remove temporary file at: $CD_PATH/$BACKUP_NAME ..."
			rm -f $CD_PATH/$BACKUP_NAME
			echo "Backup complete!!"
			BACKUP=1
		else
			echo "Could not back on archive: $CD_PATH/$BACKUP_NAME!!"
		fi
	else
		SVC=""
	fi
done
if [ 1 -eq $BACKUP ]; then
	echo "Your MongoSb Backup is stored on AWS bucket url: $MONGO_S3_BUCKET_URL/$BACKUP_NAME"
	echo "Success!!"
else
	echo "Uncomplete!!"
fi
exit 0
