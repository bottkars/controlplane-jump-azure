#!/usr/bin/env bash
source ~/.env.sh

cd ${HOME_DIR}
mkdir -p ${LOG_DIR}
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
eval "$(om --env ${HOME_DIR}/om_${ENV_NAME}.env bosh-env --ssh-private-key $HOME/opsman)"

PRODUCT_SLUG="p-control-plane-components"
PCF_VERSION="0.0.31"
RELEASE_ID="342685"
STEMCELL_VER="250.17"

TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
echo "retrieving pivnet access token from refresh token"

PIVNET_ACCESS_TOKEN=$(curl \
    --fail \
    --header "Content-Type: application/json" \
    --data "{\"refresh_token\": \"${PIVNET_UAA_TOKEN}\"}" \
    https://network.pivotal.io/api/v2/authentication/access_tokens |\
jq -r '.access_token')

echo "retrieving EULA Acceptance Link for ${PRODUCT_SLUG}"

RELEASE_JSON=$(curl \
    --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
    --fail \
"https://network.pivotal.io/api/v2/products/${PRODUCT_SLUG}/releases/${RELEASE_ID}")
# eula acceptance link
EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
jq -r '._links.eula_acceptance.href')

echo "accepting EULA Acceptance for ${PRODUCT_SLUG}"

curl \
--fail \
--header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
--request POST \
${EULA_ACCEPTANCE_URL}


## need to create a download dir

declare -a FILES=("uaa-release*" \
    "postgres-release*" \
    "garden-runc-release*" \
    "credhub-release*" \
    "control-plane*" \
    "concourse-release*" \
)

#    "bosh-dns-aliases-release*" \
# are we first time ?!
DOWNLOAD_DIR_FULL=$DOWNLOAD_DIR/$PRODUCT_SLUG/${PCF_VERSION}
mkdir -p $DOWNLOAD_DIR_FULL
echo $DOWNLOAD_DIR_FULL
for FILE in "${FILES[@]}"; do
    om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
    download-product \
    --pivnet-api-token ${PIVNET_UAA_TOKEN} \
    --pivnet-file-glob "${FILE}" \
    --pivnet-product-slug ${PRODUCT_SLUG} \
    --product-version ${PCF_VERSION} \
    --output-directory ${DOWNLOAD_DIR_FULL}
done
cp ${DOWNLOAD_DIR_FULL}/control-plane* ${HOME_DIR}

echo $(date) start uploading controlplane assets into bosh director

conductor/scripts/stemcell_loader.sh -s ${STEMCELL_VER} -i 233
eval "$(om --env ${HOME_DIR}/om_${ENV_NAME}.env bosh-env --ssh-private-key $HOME/opsman)"
bosh upload-stemcell ${DOWNLOAD_DIR}/stemcells/${STEMCELL_VER}/*bosh-stemcell*.tgz
# bosh upload-release ${DOWNLOAD_DIR_FULL}/bosh-dns-aliases-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/credhub-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/garden-runc-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/postgres-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/uaa-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/concourse-release-*.tgz

## creating vm extension vars
echo "Creating VM Extensions"


cat << EOF > ${HOME_DIR}/vm-extensions-vars.yml
---
"control-plane-lb": ${ENV_NAME}-lb
"control-plane-security-group": ${ENV_NAME}-plane-security-group
EOF

cat << EOF > ${HOME_DIR}/vm-extensions.yml
vm-extension-config:
  name: control-plane-lb
  cloud_properties:
   security_group: ((control-plane-security-group))
   load_balancer: ((control-plane-lb))
EOF

cat << EOF > ${HOME_DIR}/vm-extensions-control.yml
- type: replace
  path: /instance_groups/name=web/vm_extensions?
  value: [control-plane-lb]
EOF

om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  create-vm-extension  \
  --config vm-extensions.yml  \
  --vars-file vm-extensions-vars.yml

om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  create-vm-extension 

om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
  apply-changes 
cat << EOF > ${HOME_DIR}/bosh-vars.yml
---
external_url: https://plane.${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}
persistent_disk_type: 10240
vm_type: Standard_DS3_v2
network_name: ${ENV_NAME}-plane-subnet
azs: [zone-1,zone-2,zone-3]
wildcard_domain: "*.${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}"
uaa_url: https://uaa.${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}
uaa_ca_cert: |
  $(cat ${HOME_DIR}/fullchain.cer | awk '{printf "%s\n  ", $0}')
EOF

bosh deploy -n -d control-plane control-plane-0.0.31-rc.1.yml \
  --vars-file=./bosh-vars.yml \
  --ops-file vm-extensions-control.yml

export CREDHUB_URL="https://plane.${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}:8844"
export CLIENT_NAME="credhub_admin_client"
export credhub_password="$(credhub get -n "/p-bosh/control-plane/credhub_admin_client_password" -k password)"
export CA_CERT="$(credhub get -n /p-bosh/control-plane/control-plane-tls -k certificate)"

credhub login -s "${CREDHUB_URL}" --client-name "${CLIENT_NAME}" --client-secret "${credhub_password}" --ca-cert "${CA_CERT}"

echo "You can now login to https://plane.${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME} with below admin credentials"
echo " once logged in, use \`fly --target plane login --concourse-url https://plane.${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}\` to signin to flycli"
credhub get -n $(credhub find | grep uaa_users_admin | awk '{print $3}')