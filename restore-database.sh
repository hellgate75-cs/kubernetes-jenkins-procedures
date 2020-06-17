#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
INSTANCE="$3"
TYPE="$4"
RESTORE_FILE="$5"
SHRED_SOURCE="$6"

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

if [ "" = "$RESTORE_FILE" ]; then
	echo "Restore file is mandatory at position 5"
	echo "Abort!"
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

if [ "" = "$SHRED_SOURCE" ]; then
	SHRED_SOURCE="false"
fi

if [ "true" != "$SHRED_SOURCE" ] && [ "false" != "$SHRED_SOURCE" ]; then
	SHRED_SOURCE="false"
fi

MONGO_S3_BUCKET_URL="s3://cs-aws-backup-jenkins/mongodb/${RESTORE_FILE}.archive"
BACKUP_NAME="${RESTORE_FILE}.archive"

echo "Summary: "
echo "========="
echo " "
echo "Cluster name: $ENV"
echo "Node name: $NODE_NAME"
echo "Instance name: $INSTANCE"
echo "Application Type: $TYPE"
echo "Restore url: $MONGO_S3_BUCKET_URL"
echo "Clean source database: $SHRED_SOURCE"

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
IFS=$'\n';for ksvc in $(eval "$CMD"); do
	xsvc="$(echo "$ksvc"|awk 'BEGIN {FS=OFS=" "}{print $1}')"

	if [ "" != "$(echo "$xsvc"|grep -i external|grep -i mongodb)" ]; then
		eval "DB_PORT=\"\$(kubectl $KUBECTL_BASE get svc $xsvc -o jsonpath={.spec.ports[0].port} 2> /dev/null)\""
		echo "Restore running on host: $PUBLIC_IP and port: $DB_PORT ..."
		if [ "true" = "$SHRED_SOURCE" ]; then
			echo "Clean databases ..."
			PODNAME=`kubectl --kubeconfig=$KUBECONFIG --namespace $NAMESPACE get pods|grep mongo|head -1|awk 'BEGIN {FS=OFS=" "}{print $1}'`
			RAWLIST=`kubectl --kubeconfig=$KUBECONFIG --namespace $NAMESPACE exec -i $PODNAME -- bash <<EOF
mongo -u $USERNAME -p $PASSWORD <<DBEND
show dbs
DBEND
EOF
2> /dev/null`
			DBLIST=`echo "$RAWLIST"|grep GB|awk 'BEGIN {FS=OFS=" "}{print $1}'|grep -v local|grep -v admin`
			IFS=$'\n';for dbname in $DBLIST; do
				echo "Drop database: $dbname"
				OUT=`kubectl --kubeconfig=$KUBECONFIG --namespace $NAMESPACE exec -i $PODNAME -- bash <<EOF
mongo -u $USERNAME -p $PASSWORD <<DBEND
use $dbname
db.dropDatabase()
DBEND
EOF
2> /dev/null`
				echo "Output: $OUT"
				echo "Database  $dbname dropped!!"
			done
		fi
		echo "Downloading data from $ARCHIVE ..."
		aws s3 cp $MONGO_S3_BUCKET_URL $CD_PATH/$BACKUP_NAME
		if [ -e $CD_PATH/$BACKUP_NAME ]; then
			echo "Downloaded file information:"
			ls -latr $CD_PATH/$BACKUP_NAME
			echo "Restoring backup to mongodb -> mongo://$PUBLIC_IP:$DB_PORT ..."
			$CD_PATH/mongodb/restore-mongodb-archive.sh $PUBLIC_IP $DB_PORT $CD_PATH/$BACKUP_NAME
			echo "Removing temporary archive $CD_PATH/$BACKUP_NAME ..."
			rm -f $CD_PATH/$BACKUP_NAME
			echo "MongoDb restore complete!!"
			BACKUP=1
		else
			echo "Could not restore archive: $CD_PATH/$BACKUP_NAME!!"
		fi
	else
		SVC=""
	fi
done
if [ 1 -eq $BACKUP ]; then
	echo "Your MongoSb Backup is stored on AWS bucket url: $MONGO_S3_BUCKET_URL/$BACKUP_URL"
	echo "Success!!"
else
	echo "Uncomplete!!"
fi
exit 0
