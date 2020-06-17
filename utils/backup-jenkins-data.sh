#!/bin/sh
cd /root
SUFF="$(date +"%Y-%m-%d-%H-%M-%s")"
tar -czvf /root/jenkins-backup-data-${SUFF}.tgz jenkins -C /root 2>&1 > /dev/null
aws s3 cp /root/jenkins-backup-data-${SUFF}.tgz s3://ci-cd-general-purpose-bucket/jenkins-data-backup/
rm -f /root/jenkins-backup-data-${SUFF}.tgz
