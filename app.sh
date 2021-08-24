#!/bin/bash

set -e

# set working directory
cd "$(dirname "$0")"

tctl apply -f demo-app/tenant.yaml
sleep 3
tctl apply -f demo-app/workspace.yaml
sleep 3
tctl apply -f demo-app/groups.yaml
sleep 3

kubectl apply -f demo-app/ingress.yaml

sleep 20

export GATEWAY_IP=$(kubectl -n bookinfo get service tsb-gateway-bookinfo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo $GATEWAY_IP

kubectl -n bookinfo create secret tls bookinfo-certs --key artifacts/bookinfo.key --cert artifacts/bookinfo.crt

sleep 3

tctl apply -f demo-app/gateway.yaml


