#!/usr/bin/env bash
NAMESPACE=test
if [ "" != "$1" ]; then
	NAMESPACE="$1"
fi
echo "Namespace: $NAMESPACE"
echo "Kubeconfig: $KUBECONFIG"
kubectl --kubeconfig=$KUBECONFIG --namespace=$NAMESPACE get all|grep -v NAME|awk 'BEGIN {FS=OFS=" "}{print $1}'|xargs kubectl --kubeconfig=$KUBECONFIG --namespace=$NAMESPACE delete
kubectl --kubeconfig=$KUBECONFIG --namespace=$NAMESPACE get ingress|grep -v NAME|awk 'BEGIN {FS=OFS=" "}{print $1}'|xargs kubectl --kubeconfig=$KUBECONFIG --namespace=$NAMESPACE delete ingress
