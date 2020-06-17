#!/bin/sh
mkdir -p /var/lib/jenkins/temp
tar -czvf /var/lib/jenkins/temp/k8s-cli.tgz .k8s-cli -C /var/lib/jenkins 1>&2 > /dev/null
aws s3 cp /var/lib/jenkins/temp/k8s-cli.tgz s3://cs-aws-backup-jenkins/k8s-cli/
rm -f /var/lib/jenkins/temp/k8s-cli.tgz
