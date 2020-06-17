#!/bin/sh
cd /root
SUFF="$(date +"%Y-%m-%d-%H-%M-%s")"
tar -czvf /root/nginx-backup-data-${SUFF}.tgz nginx -C /root 2>&1 > /dev/null
aws s3 cp /root/nginx-backup-data-${SUFF}.tgz s3://ci-cd-general-purpose-bucket/nginx-data-backup/
rm -f /root/nginx-backup-data-${SUFF}.tgz
