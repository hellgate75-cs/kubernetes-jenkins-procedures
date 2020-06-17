#!/bin/sh
cd /root
SUFF="$(date +"%Y-%m-%d-%H-%M-%s")"
tar -czvf /root/k8s-cli-backup-data-${SUFF}.tgz .k8s-cli -C /root 2>&1 > /dev/null
aws s3 cp /root/k8s-cli-backup-data-${SUFF}.tgz s3://ci-cd-general-purpose-bucket/k8s-cli-backup/
rm -f /root/k8s-cli-backup-data-${SUFF}.tgz
