#!/bin/sh
eval "$(set)"
echo "Installing Mongo tools ..."
FOLDER="$(realpath "$(dirname "$0")")"
if [ "x" = "x$1" ] || [ "x-t" = "x$1" ]; then
	mkdir -p ~/go/src/github.com/mongodb
	cd ~/go/src/github.com/mongodb
	if [ -e ~/go/src/github.com/mongodb/mongo-tools ]; then
		rm -Rf ~/go/src/github.com/mongodb/mongo-tools
	fi
	git clone git@github.com:mongodb/mongo-tools.git 
	go get -u github.com/mongodb/mongo-tools
	cd mongo-tools
	if [ -e /usr/share/go ]; then
		export GOROOT=/usr/share/go
	fi
	sh -c ./build.sh
	if [ -e ./bin ]; then
		sudo cp -f ./bin/* /usr/bin/
		echo "Mongo tools installed..."
	else
		echo "Mongo tools installation failed ..."
	fi
	cd ..
	rm -Rf mongo-tools
	echo "Mongo tools installation complete!!"
else
	echo "Required skip for mongo tools installation ..."
fi
if [ "x" != "x$1" ] && [ "x-c" = "x$1" ]; then
	if [ "" != "$(which apt-get 2> /dev/null)" ]; then
		echo "Installing MongoDB client client ..."
		sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv
		echo "deb http://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
		sudo apt-get update
		sudo apt-get install -y mongodb-org-tools
		sudo apt-get autoremove -y
		sudo rm -rf /var/lib/apt/lists/*
		echo "MongoDB client installed!!"
	else
		echo "Wrong OS, apt-get is not present..."
	fi
else
	echo "Required skip for mongo client installation ..."
fi

cd $FOLDER
