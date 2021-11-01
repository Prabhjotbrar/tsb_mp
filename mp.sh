#!/bin/bash

set -e

# set working directory
cd "$(dirname "$0")"

source ./var.sh


if kubectl wait pods --for condition=ready -n cert-manager --all --timeout=120s > /dev/null 2>&1; then
  echo 'Cert manager is already installed and ready.'
else
  kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml
  kubectl wait pods --for condition=ready -n cert-manager --all --timeout=120s
fi

# install postgres
if kubectl -n default wait --for condition=ready --timeout=120s pod/tsb-postgresql-0; then
  echo "Postgres is already installed."
else
  kubectl apply -k github.com/zalando/postgres-operator/manifests
  sleep 20
#  cd ..
fi

sed  "s%#SC#%${SC}%g" artifacts/pgsql.yaml.tpl > artifacts/pgsql.yaml 
kubectl apply -f artifacts/pgsql.yaml
sleep 15

export PG_PASS=$(kubectl get secret -n default tsb-user.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o go-template='{{ .data.password | base64decode }}')
echo "PG_PASS=" $PG_PASS

kubectl apply -f https://download.elastic.co/downloads/eck/1.3.0/all-in-one.yaml
sleep 15
kubectl -n elastic-system wait --for condition=ready --timeout=120s pod/elastic-operator-0
sleep 5
kubectl apply -f artifacts/elastic.yaml
sleep 30

printf "Waiting for elastic-pods  to become ready "

while ! kubectl wait pod -n elastic  --for condition=ready --timeout=60s --all; do
  echo "waiting for elasticsearch!"
  sleep 5
done

export ELASTIC_PASS=$(kubectl get secret -n elastic tsb-es-elastic-user -o go-template='{{ .data.elastic | base64decode }}')
kubectl get secret -n elastic tsb-es-http-certs-public -o go-template='{{ index .data "ca.crt" | base64decode}}' > artifacts/es-ca-cert.pem

#install mp operator
tctl install manifest management-plane-operator \
  --registry $HUB | kubectl apply -f -
sleep 5

for i in `kubectl get pods -n tsb | grep -i teamsync | awk {'print $1'}`;do kubectl delete pod -n tsb  $i;sleep 4;done

kubectl wait pods --for condition=ready -n tsb --all --timeout=120s



tctl install manifest management-plane-secrets --tsb-admin-password admin --tsb-server-certificate "$(cat artifacts/dummy.cert.pem)" --tsb-server-key "$(cat artifacts/dummy.key.pem)" --postgres-username tsb_user --postgres-password $PG_PASS  --elastic-username elastic --elastic-password $ELASTIC_PASS --allow-defaults --elastic-ca-certificate "$(cat artifacts/es-ca-cert.pem)" --xcp-certs > artifacts/mpsecrets.yaml

sleep 3
kubectl apply -f artifacts/mpsecrets.yaml

#Install management plane CRD
sleep 20

sed  "s%#HUB#%${HUB}%g" artifacts/mgp.yaml.tpl > artifacts/mgp.yaml
kubectl apply -f artifacts/mgp.yaml
sleep 20
for i in `kubectl get pods -n tsb | grep -i teamsync | awk {'print $1'}`;do kubectl delete pod -n tsb  $i;sleep 4;done
sleep 20
kubectl wait pods --for condition=ready -n tsb --all --timeout=120s 
sleep 10


if ! kubectl get job -n tsb teamsync-bootstrap ; then

  kubectl create job -n tsb teamsync-bootstrap --from=cronjob/teamsync

fi
sleep 10
kubectl wait --for=condition=complete job/teamsync-bootstrap -n tsb --timeout=120s

#GKE:   
MP_ADDRESS=$(kubectl get svc -n tsb envoy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo -e "Management Plane created successfully. \n address: ${MP_ADDRESS} \n user: admin \n password: $TSB_PASSWORD"



sleep 10


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


