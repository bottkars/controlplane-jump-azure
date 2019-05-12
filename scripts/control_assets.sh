
source ~/.env.sh

cd ${HOME_DIR}
eval "$(om --env ${HOME_DIR}/om_${ENV_NAME}.env bosh-env --ssh-private-key $HOME/opsman)"

PRODUCT_SLUG="p-control-plane-components"
PCF_VERSION="0.0.32"
RELEASE_ID="359492"
STEMCELL_VER="250.38"

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
    "bosh-dns-aliases-release*" \
)
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


echo $(date) start downloading controlplane assets

conductor/scripts/stemcell_loader.sh -s ${STEMCELL_VER} -i 233
eval "$(om --env ${HOME_DIR}/om_${ENV_NAME}.env bosh-env --ssh-private-key $HOME/opsman)"
bosh upload-stemcell ${DOWNLOAD_DIR}/stemcells/${STEMCELL_VER}/*bosh-stemcell*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/bosh-dns-aliases-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/credhub-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/garden-runc-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/postgres-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/uaa-release-*.tgz
bosh upload-release ${DOWNLOAD_DIR_FULL}/concourse-release-*.tgz
