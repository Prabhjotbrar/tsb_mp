# tsb_installation

1. Update  variables in var.sh
```
HUB="<private registry>"
TSB_PASSWORD="<password>"
SC="<local-shared>"  -- storage class for PV 
CLUSTER_NAME="<<kubernetes cluster name>>"
MP_CLUSTER="<<tsb cluster name>>"
ZONE=""
PROJECT=""
```
2. Sync the docker images needed for deployment 

3. Setup tctl client
 ./tctl.sh

4.install management and control plane
 ./mp.sh
