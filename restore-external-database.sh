#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

HOSTNAME="$1"
DB_PORT="$2"
RESTORE_FILE="$3"
SHRED_SOURCE="$4"

if [ "" = "$HOSTNAME" ]; then
	echo "Hostname is mandatory at args position 1"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$DB_PORT" ]; then
	echo "Db Port name is mandatory at args position 2"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$RESTORE_FILE" ]; then
	echo "Restore file is mandatory at position 3"
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
echo "Hostname or Ip Address: $HOSTNAME"
echo "Database Port: $DB_PORT"
echo "Restore url: $MONGO_S3_BUCKET_URL"
echo "Clean source database: $SHRED_SOURCE"


PUBLIC_IP="$HOSTNAME"

echo "Public Ip: $PUBLIC_IP"
BACKUP=0
#Mongo parameters
USERNAME="root"
PASSWORD="aangine1234@"
AUTH_DB="admin"
echo "Restore running on host: $PUBLIC_IP and port: $DB_PORT ..."
if [ "true" = "$SHRED_SOURCE" ]; then
	echo "Clean databases ..."
	RAWLIST=`docker run -it hellgate75/mongo-cli bash -c "mkdir -p /home/mongodb && touch /home/mongodb/.dbshell && echo \"\" > /home/mongodb/.dbshell && mongo --host $HOSTNAME --port $DB_PORT -u $USERNAME -p $PASSWORD <<DBEND
show dbs
DBEND
2>dev/null"`
	DBLIST=`echo "$RAWLIST"|grep GB|awk 'BEGIN {FS=OFS=" "}{print $1}'|grep -v local|grep -v admin`
	IFS=$'\n';for dbname in $DBLIST; do
		echo "Drop database: $dbname"
		OUT=`docker run -it hellgate75/mongo-cli bash -c "mkdir -p /home/mongodb && touch /home/mongodb/.dbshell && echo \"\" > /home/mongodb/.dbshell && mongo --host $HOSTNAME --port $DB_PORT -u $USERNAME -p $PASSWORD <<DBEND
mongo -u $USERNAME -p $PASSWORD <<DBEND
use $dbname
db.dropDatabase()
DBEND
2> /dev/null"`
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
if [ 1 -eq $BACKUP ]; then
	echo "Your MongoSb Backup is stored on AWS bucket url: $MONGO_S3_BUCKET_URL/$BACKUP_URL"
	echo "Success!!"
else
	echo "Uncomplete!!"
fi
exit 0
