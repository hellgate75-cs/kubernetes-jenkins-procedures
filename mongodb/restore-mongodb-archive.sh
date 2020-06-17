#!/bin/bash
IPADDRESS=`ifconfig eth0|grep inet|head -1|awk 'BEGIN {FS=OFS=" "}{print $2}'`
if [ "" != "$1" ]; then
	IPADDRESS="$1"
fi
if [ "" = "$IPADDRESS" ]; then
	IPADDRESS="localhost"
fi
PORT="27017"
if [ "" != "$2" ]; then
	PORT="$2"
fi
ARCHIVE="aangineQA11Oct2019202004221516.archive"
if [ "" != "$3" ]; then
	ARCHIVE="$3"
fi
echo "Restoring mongodb data:"
echo "======================="
echo "Ip: $IPADDRESS"
echo "Port: $PORT"
echo "Archive: $ARCHIVE"
echo ""
echo ""
if [ ! -e $ARCHIVE ]; then
	echo "Archive $ARCHIVE doesn't exist!"
	exit 1
fi
echo "Starting MongoDb Data Restore ..."
mongorestore --gzip --drop --host $IPADDRESS --port $PORT --username root --password aangine1234@ --authenticationDatabase admin  --archive=$ARCHIVE
echo "MongoDb Data Restore complete!!"
