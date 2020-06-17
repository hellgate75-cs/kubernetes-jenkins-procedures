#!/usr/bin/env bash

function installPackages() {
	apt-get update && apt-get install -y $@ && apt-get autoremove && rm -rf /var/lib/apt/lists/*
}

echo "Installing packages ..."
installPackages vim wget git build-essential openssh-server jq yq
echo "Creating the GoPath ..."
mkdir -p ~/go/bin
if [ "--create-keys" = "$1" ] && [ "" != "$2" ] && [ "" != "$3" ]; then
	echo "Creating the ssh root folder ..."
	mkdir -p ~/.ssh
	echo "Creating ssh root keys ..."
	echo -e "\n\n\n" > ssh-keygen -t rsa 
	ssh-keyscan github.com >> githubKey
	ssh-keygen -lf githubKey
	cat githubKey > ~/.ssh/known_hosts
	chmod 600 ~/.ssh/*
	git config --global user.name "$2"
	git config --global user.email "$3"
fi
export GOINST=/usr/share/go
export GOVER="$(wget -q -O - https://golang.org/doc/devel/release.html | grep "<h2 id=\"go" | awk 'BEGIN {FS=OFS=" "}{print $2}' | awk 'BEGIN {FS=OFS="\""}{print $2}'|head -1|awk 'BEGIN {FS=OFS="go"}{print $2}')"
export ARCH=amd64
export OS=linux
#GIT_USER=hellgate75
#GIT_EMAIL=hellgate75@gmail.com
echo "Latest detected Go Language version is $GOVER"
rm -f ~/install-golang-prereq.sh
wget -Lq https://dl.google.com/go/go${GOVER}.${OS}-${ARCH}.tar.gz -O ~/go${GOVER}.${OS}-${ARCH}.tar.gz
tar -xzf ~/go${GOVER}.${OS}-${ARCH}.tar.gz -C /usr/share/
rm -Rf ~/go${GOVER}.${OS}-${ARCH}.tar.gz
chmod 777 ${GOINST}/bin/*
echo "GOROOT=/usr/share/go" >> ~/.bashrc
echo "GOINST=/usr/share/go" >> ~/.bashrc
echo "GOPATH=$(realpath "~/go")" >> ~/.bashrc
echo "PATH=$PATH:\$GOINST/bin:\$GOPATH/bin" >> ~/.bashrc
source ~/.bashrc
go get -u  github.com/mdempsky/gocode &&\
go get -u golang.org/x/tools/... &&\
go get -u github.com/golang/dep/cmd/dep &&\
go get -u github.com/golangci/golangci-lint/cmd/golangci-lint
ln -s -T ~/go/bin/golangci-lint ~/go/bin/golint &&\
go version
rm -f ~/install-golang.sh
