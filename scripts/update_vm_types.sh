#!/usr/bin/env bash
source ~/.env.sh
MYSELF=$(basename $0)
echo "this is the vm type updater"

###  

TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)

export TF_VAR_subscription_id=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
export TF_VAR_client_secret=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export TF_VAR_client_id=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export TF_VAR_tenant_id=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)

### updating vm types
az login --service-principal \
-u $TF_VAR_client_id \
-p $TF_VAR_client_secret \
--tenant $TF_VAR_tenant_id

E_TYPES=$(az vm list-sizes -o json --location westeurope --query "[?contains(name,'Standard_E')] | [?contains(name,'s_v3')]" | jq .[])
F_TYPES=$(az vm list-sizes -o json --location ${LOCATION} --query "[?contains(name,'Standard_F')]" | jq .[])
DSv2_TYPES=$(az vm list-sizes -o json --location ${LOCATION} --query "[?contains(name,'Standard_DS')] | [?contains(name,'_v2')]" | jq .[])
Dsv3_TYPES=$(az vm list-sizes -o json --location ${LOCATION} --query "[?contains(name,'Standard_D')] | [?contains(name,'s_v3')]" | jq .[])

az logout

EXISTING_TYPES=$(om --env $HOME/om_${ENV_NAME}.env \
curl --path /api/v0/vm_types  \
--request GET | jq .vm_types[])

om --env $HOME/om_${ENV_NAME}.env \
   curl --path /api/v0/vm_types \
   --request PUT \
--data $(echo $DSV2_TYPES $Dsv3_TYPES $F_TYPES $E_TYPES |  \
jq -sc '{"vm_types": [.[] | {"name": .name, "ram": .memoryInMb, "ephemeral_disk": .resourceDiskSizeInMb, "cpu": .numberOfCores}]}')



