#!/bin/sh
GROUP="aangine"
if [ "" != "$1" ]; then
	GROUP="$1"
fi
if [ ! -e ./kubernetes-$GROUP-charts ]; then
  git clone git@gitlab.com:aangine/kubernetes/kubernetes-$GROUP-charts.git  2> /dev/null
fi
if [ -e ./kubernetes-$GROUP-charts ]; then
  chmod -f 777 ./kubernetes-$GROUP-charts/*.sh 2> /dev/null
fi

if [ -e ./kubernetes-$GROUP-charts/install-tools.sh ]; then
  bash -c kubernetes-$GROUP-charts/install-tools.sh 2> /dev/null
fi
if [ -e ./kubernetes-$GROUP-charts/bin ]; then
  cp -R ./kubernetes-$GROUP-charts/bin ./ 2> /dev/null
  cp -f ./kubernetes-$GROUP-charts/bin/* /usr/sbin 2> /dev/null
fi
