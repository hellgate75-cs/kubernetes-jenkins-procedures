#!/bin/sh
echo -e "connecting to AWS New Jenkins : CS Jenkins"
ssh -o StrictHostKeyChecking=no -q -i certs/mambas-generic.pem ubuntu@18.156.94.155
#scp install-golang.sh root@85.159.212.85:/root/
