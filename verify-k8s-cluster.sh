#!/bin/bash
FOLDER="$(realpath "$(dirname "$0")")"
CD_PATH="$(realpath "$(dirname "$0")")"
#'${params.Environment}' '${params.Instance}'

source $CD_PATH/addson.sh

ENV="$1"
NODE_NAME="$2"
INSTANCE="$3"
TYPE="$4"
CERTFILE="${5}"

if [ "" = "$ENV" ]; then
	echo "Environment is mandatory at args position 1"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$INSTANCE" ]; then
	echo "Instance name is mandatory at args position 2"
	echo "Abort!!"
	exit 1
fi

if [ "" = "$NODE_NAME" ] || [ "NO_NODE" == "$NODE_NAME" ]; then
	NODES="$( k8s-cli -command show -subject nodes  -cluster-name $ENV | jq -r .content[].name 2> /dev/null|grep -v null)"
	if [ "" = "$NODES" ]; then
		echo "Cannot recover nodes for cluster: $ENV"
		echo "Abort!"
		exit 1
	fi
	NODE_NAME=""
	IFS=$'\n';for nd in $NODES; do
		if [ "" = "$NODE_NAME" ]; then
			INSTS="$(k8s-cli -command show -subject instances -cluster-name $ENV -node-name $nd 2> /dev/null|jq -r .content[].name|grep -v null)"
			if [ "" != "$INSTS" ]; then
				IFS=$'\n';for is in $INSTS; do
					if [ "$is" = "$INSTANCE" ]; then
						NODE_NAME="$nd"
					fi
				done
			fi
		fi
	done
fi

if [ "" = "$NODE_NAME" ]; then
	echo "Node of cluster $ENV, Instance: $INSTANCE was not found!!"
	echo "Abort!"
	exit 1
fi

echo "Summary: "
echo "========="
echo " "
echo "Cluster name: $ENV"
echo "Node name: $NODE_NAME"
echo "Instance name: $INSTANCE"
echo "Application Type: $TYPE"
if [ "" = "$CERTFILE" ]; then
	echo "SSH Certificate/Key is mandatory at args position 5: setting default value: certs/mambas-generic.pem"
	CERTFILE="certs/mambas-generic.pem"
fi
echo "SSH Certificate path: $CERTFILE"

PREPARATION_ENV="$(k8s-cli -command prepare -subject instance -cluster-name $ENV -node-name $NODE_NAME  -instance-name $INSTANCE | jq -r .content | grep -v null)"
if [ "" = "$PREPARATION_ENV" ]; then
	echo "Instance $INSTANCE not prepared for errors"
	echo "Abort!!"
	exit 1
fi
echo "Source file: $PREPARATION_ENV"

eval "$(cat $PREPARATION_ENV 2>/dev/null)"

if [ "" = "$CLUSTER_INDEX" ] || [ "number" != "$(variableType $CLUSTER_INDEX)" ]; then
	echo "Couldn't recover cluster index for instance $INSTANCE..."
	echo "Abort!!"
	exit 1
fi

HOSTNAME="$(k8s-cli  -command details  -subject node -cluster-name $ENV -node-name $NODE_NAME|jq -r .hostname|grep -v null)"

if [ "" = "$HOSTNAME" ]; then
	echo "Unable to recover hostname for cluster: $ENV for node: $NODE_NAME"
	echo "Abort!!"
	exit 1
fi

echo "Hostname: $HOSTNAME"

PUBLIC_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp' --output text|grep -v None)"
PRIVATE_IP="$(aws ec2 describe-instances --filter "Name=private-dns-name,Values=$HOSTNAME" --query 'Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddress' --output text|grep -v None)"

if [ "" = "$PUBLIC_IP" ]; then
	echo "Unable to recover public ip for cluster: $ENV in node: $NODE_NAME for hostname: $HOSTNAME"
	echo "Abort!!"
	exit 1
fi
#--kubeconfig=$KUBECONFIG --namespace=$NAMESPACE get ingress nginx-ingress -o jsonpath={.status.loadBalancer.ingress[0].ip}
#kubectl --kubeconfig=$KUBECONFIG --namespace=$NAMESPACE get ingress nginx-ingress -o jsonpath={.spec.backend.servicePort}
echo "Public Ip: $PUBLIC_IP"
CMD="kubectl $KUBECTL_BASE get svc 2> /dev/null|grep -v NAME"
OUT="{"
COUNT=0
MONGO=0
IFS=$'\n';for ksvc in $(eval "$CMD"); do
	xsvc="$(echo "$ksvc"|awk 'BEGIN {FS=OFS=" "}{print $1}')"

	if [ "" != "$(echo "$xsvc"|grep -i external|grep -i consul)" ]; then
#		PORTTYPE="nodeport"
		SVC="$xsvc"
		APP="Consul"
	elif [ "" != "$(echo "$xsvc"|grep -i external|grep -i jaeger|grep -i query)" ]; then
#		PORTTYPE="nodeport"
		SVC="$xsvc"
		APP="Jaeger"
	elif [ "" != "$(echo "$xsvc"|grep -i external|grep -i nginx)" ]; then
#		PORTTYPE="nodeport"
		SVC="$xsvc"
		APP="Nginx UI"
	elif [ "" != "$(echo "$xsvc"|grep -i external|grep -i mongodb)" ]; then
#		PORTTYPE="nodeport"
		SVC="$xsvc"
		APP="Mongo Db"
		MONGO=1
	else
		SVC=""
	fi
	if [ "" != "$SVC" ]; then
#		eval "IP_SVC=\"\$(kubectl $KUBECTL_BASE get svc $SVC -o jsonpath={.status.loadBalancer.ingress[0].ip} 2> /dev/null)\""
		eval "PORT=\"\$(kubectl $KUBECTL_BASE get svc $SVC -o jsonpath={.spec.ports[0].port} 2> /dev/null)\""
		if [ "" != "$PORT" ]; then
			if [ 0 -eq $MONGO ]; then
				let COUNT=COUNT+1
	#			OUT="$OUT \"$APP\": \"http://${IP_SVC}:${PORT}/\","
	#			echo "$APP: http://${IP_SVC}:${PORT}/"
				OUT="$OUT \"$APP\": \"http://${PUBLIC_IP}:${PORT}/\","
				echo "$APP: http://${PUBLIC_IP}:${PORT}/"
			else
				let COUNT=COUNT+2
				OUT="$OUT \"$APP Public\": \"mongo://${PUBLIC_IP}:${PORT}/\","
				echo "$APP Public: mongo://${PUBLIC_IP}:${PORT}/"
				OUT="$OUT \"$APP Private\": \"mongo://${PRIVATE_IP}:${PORT}/\","
				echo "$APP Private: mongo://${PRIVATE_IP}:${PORT}/"
			fi
		fi
	fi
done
OUT="$OUT \"ports\": $COUNT }"
echo "$OUT"
echo "Success!!"
exit 0
