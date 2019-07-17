#!/usr/bin/env bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--HOME)
    HOME_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if  [ -z ${HOME_DIR} ] ; then
 echo "Please specify HOME DIR -h|--HOME"
 exit 1
fi 

cd ${HOME_DIR}
source ${HOME_DIR}/.env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
function retryop()
{
  retry=0
  max_retries=$2
  interval=$3
  while [ ${retry} -lt ${max_retries} ]; do
    echo "Operation: $1, Retry #${retry}"
    eval $1
    if [ $? -eq 0 ]; then
      echo "Successful"
      break
    else
      let retry=retry+1
      echo "Sleep $interval seconds, then retry..."
      sleep $interval
    fi
  done
  if [ ${retry} -eq ${max_retries} ]; then
    echo "Operation failed: $1"
    exit 1
  fi
}
###
pushd ${HOME_DIR}
### updating om


#  FAKING TERRAFORM DOWNLOAD FOR Control Plane
PRODUCT_SLUG="elastic-runtime"
RELEASE_ID="363705"
#
OM_VER=2.0.1
wget -O om https://github.com/pivotal-cf/om/releases/download/${OM_VER}/om-linux-${OM_VER} && \
  chmod +x om && \
  sudo mv om /usr/local/bin/
###  

TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)

export TF_VAR_subscription_id=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
export TF_VAR_client_secret=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export TF_VAR_client_id=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export TF_VAR_tenant_id=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)


AUTHENTICATION_RESPONSE=$(curl \
  --fail \
  --data "{\"refresh_token\": \"${PIVNET_UAA_TOKEN}\"}" \
  https://network.pivotal.io/api/v2/authentication/access_tokens)

PIVNET_ACCESS_TOKEN=$(echo ${AUTHENTICATION_RESPONSE} | jq -r '.access_token')
# Get the release JSON for the CONTROLPLANE version you want to install:

RELEASE_JSON=$(curl \
    --fail \
    "https://network.pivotal.io/api/v2/products/${PRODUCT_SLUG}/releases/${RELEASE_ID}")

# ACCEPTING EULA

EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
  jq -r '._links.eula_acceptance.href')

curl \
  --fail \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --request POST \
  ${EULA_ACCEPTANCE_URL}

# GET TERRAFORM FOR CONTROLPLANE AZURE


DOWNLOAD_ELEMENT=$(echo ${RELEASE_JSON} |\
  jq -r '.product_files[] | select(.aws_object_key | contains("terraforming-azure"))')

FILENAME=$(echo ${DOWNLOAD_ELEMENT} |\
  jq -r '.aws_object_key | split("/") | last')

URL=$(echo ${DOWNLOAD_ELEMENT} |\
  jq -r '._links.download.href')

# download terraform

curl \
  --fail \
  --location \
  --output ${FILENAME} \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  ${URL}
unzip ${FILENAME}
cd ./pivotal-cf-terraforming-azure-*/
export PROJECT_DIR=$(pwd)
cd terraforming-control-plane
wget https://raw.githubusercontent.com/bottkars/terraforming-azure/patch-1/ci/assets/template/director-config.yml -O ../ci/assets/template/director-config.yml
wget https://raw.githubusercontent.com/bottkars/terraforming-azure/patch-1/scripts/configure-director -O ../scripts/configure-director
wget https://raw.githubusercontent.com/bottkars/terraforming-azure/patch-1/modules/control_plane/main.tf -O ../modules/control_plane/main.tf
cat << EOF > terraform.tfvars
env_name              = "${ENV_NAME}"
ops_manager_image_uri = "${OPS_MANAGER_IMAGE_URI}"
location              = "${LOCATION}"
dns_suffix            = "${CONTROLPLANE_DOMAIN_NAME}"
dns_subdomain         = "${CONTROLPLANE_SUBDOMAIN_NAME}"
ops_manager_private_ip = "${NET_16_BIT_MASK}.8.4"
pcf_infrastructure_subnet = "${NET_16_BIT_MASK}.8.0/26"
plane_cidr = "${NET_16_BIT_MASK}.10.0/28"
pcf_virtual_network_address_space = ["${NET_16_BIT_MASK}.0.0/16"]
EOF

# Get Azure Secrets and stuff from keyvauls
terraform init

retryop "terraform apply -auto-approve" 3 10

terraform output ops_manager_ssh_private_key > ${HOME_DIR}/opsman
chmod 600 ${HOME_DIR}/opsman

declare -a FILES=("${HOME_DIR}/${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}.key" \
"${HOME_DIR}/fullchain.cer")
# are we first time ?!

for FILE in "${FILES[@]}"; do
    if [ ! -f $FILE ]; then
      if [ "${USE_SELF_CERTS}" = "TRUE" ]; then
        ${SCRIPT_DIR}/create_self_certs.sh
      else  
        ${SCRIPT_DIR}/create_certs.sh
      fi
    fi  
done
## did let´sencrypt just not work ?
for FILE in "${FILES[@]}"; do
    if [ ! -f $FILE ]; then
    echo "$FILE not found. running Create Self Certs "
    ${SCRIPT_DIR}/create_self_certs.sh
    fi
done


PCF_OPSMAN_FQDN="$(terraform output ops_manager_dns)"
echo "checking opsman api ready using the new fqdn ${PCF_OPSMAN_FQDN},
if the . keeps showing, check if ns record for $(terraform output control_plane_domain) has
$(terraform output env_dns_zone_name_servers)
as server entries"
until $(curl --output /dev/null --silent --head --fail -k -X GET "https://${PCF_OPSMAN_FQDN}/api/v0/info"); do
    printf '.'
    sleep 5
done
echo "done"

OM_ENV_FILE="${HOME_DIR}/om_${ENV_NAME}.env"
### change method back to not store OM Password going forward
cat << EOF > ${OM_ENV_FILE}
---
target: ${PCF_OPSMAN_FQDN}
connect-timeout: 30          # default 5
request-timeout: 3600        # default 1800
skip-ssl-validation: true   # default false
username: ${OPSMAN_USERNAME}
password: ${PIVNET_UAA_TOKEN}
decryption-passphrase: ${PIVNET_UAA_TOKEN}
EOF


export CA_CERT=$(cat ${HOME_DIR}/fullchain.cer | awk '{printf "%s\\r\\n", $0}')

../scripts/configure-director terraforming-control-plane ${PIVNET_UAA_TOKEN} ${OPSMAN_USERNAME}


###

retryop "om --env "${HOME_DIR}/om_${ENV_NAME}.env"  apply-changes" 2 10

echo checking deployed products
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
deployed-products

om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
update-ssl-certificate \
    --certificate-pem "$(cat ${HOME_DIR}/fullchain.cer)" \
    --private-key-pem "$(cat ${HOME_DIR}/${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}.key)"


echo checking deployed products
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
 deployed-products


popd
echo "opsman deployment finished at $(date)"


if [ "${CONTROLPLANE_AUTOPILOT}" = "TRUE" ]; then
    evho "Starting Control Plane Deployment"
    ${SCRIPT_DIR}/deploy_controlplane.sh 
fi    
