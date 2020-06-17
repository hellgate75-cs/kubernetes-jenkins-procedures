#!/bin/sh
go get -u github.com/hellgate75/k8s-cli
sudo cp -f ~/go/bin/k8s-cli* /usr/sbin
if [ "" != "$(which docker)" ]; then
	if [ "" != "$(docker ps -a|grep -v NAME|grep jenkins)" ]; then
		docker exec -it jenkins bash -c "cd /root & source /root/.bashrc && /usr/share/go/bin/go get -u github.com/hellgate75/k8s-cli"
		docker exec -it jenkins bash -c "cp -f ~/go/bin/k8s-cli* /usr/sbin"
	fi
fi
