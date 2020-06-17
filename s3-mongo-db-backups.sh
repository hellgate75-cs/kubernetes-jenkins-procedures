#!/bin/bash
list="["
IFS=$'\n'; for file in $(aws s3 ls cs-aws-backup-jenkins/mongodb/|grep archive|awk 'BEGIN {FS=OFS=" "}{print $NF}'); do
	if [ "x[" != "x$list" ]; then
		list="$list,"
	fi
	list="$list\"$(echo $file|awk 'BEGIN {FS=OFS="."}{print $1}')\""
done
list="$list]"
echo "$list"
