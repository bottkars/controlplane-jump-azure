
source ~/.env.sh

cd ${HOME_DIR}
eval "$(om --env ${HOME_DIR}/om_${ENV_NAME}.env bosh-env --ssh-private-key $HOME/opsman)"

PRODUCT_SLUG="p-control-plane-components"
PCF_VERSION="0.0.32"
RELEASE_ID="359492"
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

for FILE in "${FILES[@]}"; do
    om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
        download-product \
        --pivnet-api-token ${PIVNET_UAA_TOKEN} \
        --pivnet-file-glob "${FILE}" \
        --pivnet-product-slug ${PRODUCT_SLUG} \
        --product-version ${PCF_VERSION} \
        --output-directory ${HOME_DIR}
done


echo $(date) start downloading kubectl

conductor/scripts/stemcell_loader.sh -s 250.38 -i 233
eval "$(om --env ${HOME_DIR}/om_${ENV_NAME}.env bosh-env --ssh-private-key $HOME/opsman)"



bosh upload-stemcell *bosh-stemcell*.tgz
bosh upload-release concourse-release-*.tgz
bosh upload-release credhub-release-*.tgz
bosh upload-release garden-runc-release-*.tgz
bosh upload-release postgres-release-*.tgz
bosh upload-release uaa-release-*.tgz
