## deploy
if not already done,  
create an ssh keypair for the environment  




```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

deployment using the default parameters only passes a minimum required parameters to the az command. all other values are set to their default.

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment validate --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/concourse-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    CONCOURSEDomainName=${CONCOURSE_DOMAIN_NAME} \
    CONCOURSESubdomainName=${CONCOURSE_SUBDOMAIN_NAME} \
    opsmanUsername=${OPSMAN_USERNAME} \
    keyVaultName=${AZURE_VAULT} \
    keyVaultRG=${VAULT_RG} \
    _artifactsLocation=${ARTIFACTS_LOCATION} \
    vmSize=${VMSIZE}
```

### validate using customized parameters

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/concourse-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    CONCOURSEDomainName=${CONCOURSE_DOMAIN_NAME} \
    CONCOURSESubdomainName=${CONCOURSE_SUBDOMAIN_NAME} \
    opsmanUsername=${OPSMAN_USERNAME} \
    keyVaultName=${AZURE_VAULT} \
    keyVaultRG=${VAULT_RG} \
    _artifactsLocation=${ARTIFACTS_LOCATION} \
    vmSize=${VMSIZE}
```

installation using customized parameter set´s all required parameters from variables in your .env file

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/concourse-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    opsmanImage=${OPS_MANAGER_IMAGE} \
    CONCOURSEDomainName=${CONCOURSE_DOMAIN_NAME} \
    CONCOURSESubdomainName=${CONCOURSE_SUBDOMAIN_NAME} \
    opsmanUsername=${OPSMAN_USERNAME} \
    notificationsEmail=${CONCOURSE_NOTIFICATIONS_EMAIL} \
    CONCOURSEAutopilot=${CONCOURSE_AUTOPILOT} \
    net16bitmask=${NET_16_BIT_MASK} \
    useSelfCerts=${USE_SELF_CERTS} \
    _artifactsLocation=${ARTIFACTS_LOCATION} \
    vmSize=${VMSIZE} \
    opsmanImage=${OPS_MANAGER_IMAGE} \
    opsmanImageRegion=${OPS_MANAGER_IMAGE_REGION}
```