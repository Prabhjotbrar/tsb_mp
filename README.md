# tsb_installation

1.update the variable in var.sh

HUB="<private registry>"
TSB_PASSWORD="<password>"
SC="<local-shared>"  -- storage class for PV 
CLUSTER_NAME="<<kubernetes cluster name>>"
MP_CLUSTER="<<tsb cluster name>>"
ZONE=""
PROJECT=""

2. Sync the images needed for deployment 

3. Setup tctl client
 ./tctl.sh

4.install management and control plane
  ./mp.sh
