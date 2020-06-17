#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

HOSTNAME="$1"
PORT="$2"
BACKUP_PREFIX="$3"

if [ "" = "$HOSTNAME" ]; then
	echo "HOSTNAME is mandatory at args position 1"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$PORT" ]; then
	echo "PORT name is mandatory at args position 2"
	echo "Abort!!"
	exit 1
fi


if [ "" = "$BACKUP_PREFIX" ]; then
	echo "BACKUP_PREFIX name is optional at args position 3"
	echo "Replaging with value: aagineQA"
	BACKUP_PREFIX="aagineQA"
fi

BACKUP_NAME="${BACKUP_PREFIX}$(date +"%Y%m%d%H%M").archive"

echo " "
echo " "
echo "Summary: "
echo "========="
echo " "
echo "MongoDb Hostname: $HOSTNAME"
echo "MongoDb Port: $PORT"
echo "Backup name: $BACKUP_NAME"
echo " "
echo " "

USERNAME="root"
PASSWORD="aangine1234@"
AUTH_DB="admin"
MONGO_S3_BUCKET_URL="s3://cs-aws-backup-jenkins/mongodb"

echo "Backup running on host: $HOSTNAME and port: $PORT ..."
mongodump --host $HOSTNAME --port $PORT --username $USERNAME --password $PASSWORD --authenticationDatabase $AUTH_DB --gzip --archive=$CD_PATH/$BACKUP_NAME
if [ -e $CD_PATH/$BACKUP_NAME ]; then
	echo "Remove temporary file at: $CD_PATH/$BACKUP_NAME ..."
	aws s3 cp $CD_PATH/$BACKUP_NAME $MONGO_S3_BUCKET_URL/$BACKUP_NAME
	echo "Remove temporary file at: $CD_PATH/$BACKUP_NAME ..."
	rm -f $CD_PATH/$BACKUP_NAME
	echo "Backup complete!!"
	echo "Your MongoSb Backup is stored on AWS bucket url: $MONGO_S3_BUCKET_URL/$BACKUP_NAME"
	echo "Success!!"
	exit 0
else
	echo "Could not back on archive: $CD_PATH/$BACKUP_NAME!!"
	echo "Uncomplete!!"
	exit 1
fi
