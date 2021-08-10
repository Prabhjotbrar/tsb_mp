#!/bin/bash

set -e

source ./var.sh

gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT

KUBE_CONTEXT="gke_${PROJECT}_${ZONE}_${CLUSTER_NAME}"

kubectl config use-context ${KUBE_CONTEXT}

MP_ADDRESS=$(kubectl get svc -n tsb envoy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export ELASTIC_PASS=$(kubectl get secret -n elastic tsb-es-elastic-user -o go-template='{{ .data.elastic | base64decode }}')
tctl config clusters set $MP_CLUSTER --bridge-address ${MP_ADDRESS}:8443 --tls-insecure

tctl config profiles set $MP_CLUSTER --cluster $MP_CLUSTER

tctl config profiles  set-current $MP_CLUSTER

TCTL_LOGIN_ORG=tetrate TCTL_LOGIN_TENANT=tetrate TCTL_LOGIN_USERNAME=admin TCTL_LOGIN_PASSWORD=${TSB_PASSWORD} tctl login

sed "s%#CP_CLUSTER#%${CLUSTER_NAME}%g" artifacts/cp-cluster.yaml.tpl > artifacts/cp-cluster.yaml

tctl apply -f artifacts/cp-cluster.yaml

tctl install manifest cluster-operators --registry $HUB | kubectl apply -f -


tctl install manifest control-plane-secrets  --allow-defaults  --elastic-password $ELASTIC_PASS --elastic-username elastic  --elastic-ca-certificate "$(cat artifacts/es-ca-cert.pem)" --cluster $CLUSTER_NAME --xcp-certs "$(tctl install cluster-certs --cluster $CLUSTER_NAME)" | kubectl apply -f -

if kubectl create secret generic cacerts -n istio-system --from-file artifacts/ca-cert.pem --from-file artifacts/ca-key.pem --from-file artifacts/root-cert.pem --from-file artifacts/cert-chain.pem;then
  echo "cacerts  installed"
  fi


sed "s%#HUB#%${HUB}%g;s%#MP_HOST#%${MP_ADDRESS}%g;s%#CP_CLUSTER#%${CLUSTER_NAME}%g" artifacts/cp.yaml.tpl > artifacts/cp.yaml
sleep 40
kubectl apply -f artifacts/cp.yaml







