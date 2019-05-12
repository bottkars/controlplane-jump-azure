# controlplane-jump-azure

This Repo set´s up the "Control Plane" for Pivotal Platform Automation from a JumpHost on Azure

in Addition to the [Documentation](http://docs.pivotal.io/platform-automation/), Azure KeyVault an System managed identities are used to
Store Secrets and Credentials

You will need

- An Azure Subscription
- A Service Principal
- A Pivotal Network Refresh Token 
- local machine with azure az cli

With this Guide you Create

- a Key Vault
- A JumpHost on Azure with [Sytem Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-linux-vm-access-nonaad) to Access the Vault
- An PCF Operation Manager

This Repo will Provide

- an Azure (nested) Arm Template to create a Linux JumpBox
- assign System Managed Identities to the JumpHost

## getting started

the next steps are to be performed on your local host

### Prepare Azure Key Vault

use your existing or new key-vault to store secrets.
The Template to deploy the JumpBox assumes that the Key-Vault is in the Same subscription but different ResourceGroup

#### create the keyvault

```bash
AZURE_VAULT=<your vaultname, name must be unique fro AZURE_VAULT.vault.azure.com>
VAULT_RG=<your Vault Resource Group>
LOCATION=<azure location, e.g. westus, westeurope>
## Create RG to set your KeyVault
az group create --name ${VAULT_RG} --location ${LOCATION}
## Create keyVault
az keyvault create --name ${AZURE_VAULT} --resource-group ${VAULT_RG} --location ${LOCATION}
```

#### Assign values to the secrets

```bash
## Set temporary Variables
AZURE_CLIENT_ID=<your application ID for the Service Principal>
AZURE_TENANT_ID=<Tenant ID to be used>
AZURE_CLIENT_SECRET=<Client Secret created>
PIVNET_UAA_TOKEN=<your pivnet refresh token>
## SET the Following Secrets from the temporary Variables
az keyvault secret set --vault-name ${AZURE_VAULT} --name "AZURECLIENTID" --value ${AZURE_CLIENT_ID}
az keyvault secret set --vault-name ${AZURE_VAULT} --name "AZURETENANTID" --value ${AZURE_TENANT_ID}
az keyvault secret set --vault-name ${AZURE_VAULT} --name "PIVNETUAATOKEN" --value  ${PIVNET_UAA_TOKEN}
az keyvault secret set --vault-name ${KEY_VAULT} --name "AZURECLIENTSECRET" --value  ${AZURE_CLIENT_SECRET}
## unset the temporary variables
unset AZURE_CLIENT_ID
unset AZURE_TENANT_ID
unset AZURE_CLIENT_SECRET
unset PIVNET_UAA_TOKEN
```

## Prepare local env file

we will need local env file *or* a template parameter file variables to store names parameters used during deployment

example minimum .env file:
```bash
AZURE_VAULT=<your vault name>
VAULT_RG=<your vault rg>
IAAS=azure
JUMPBOX_RG=<your resource group for the jumpbox>
JUMPBOX_NAME=<your dns name for the jumpbox e.g. myccjumpbox>
ADMIN_USERNAME=<admin username for the jumpox>
ENV_NAME=control
ENV_SHORT_NAME=cckb
CONTROLPLANE_DOMAIN_NAME=<your domain, e.g. domain.com>
CONTROLPLANE_SUBDOMAIN_NAME=<your subdomain for control plane, e.g.control>
```

source the env file with

```bash
source ~/.env
```

## create ssh key for the jumpbox

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

## start deployment

### validate all things

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment validate --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/controlplane-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    CONTROLPLANEDomainName=${CONTROLPLANE_DOMAIN_NAME} \
    CONTROLPLANESubdomainName=${CONTROLPLANE_SUBDOMAIN_NAME} \
    keyVaultName=${AZURE_VAULT} \
    keyVaultRG=${VAULT_RG} \
```

### deploy all things

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/controlplane-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    CONTROLPLANEDomainName=${CONTROLPLANE_DOMAIN_NAME} \
    CONTROLPLANESubdomainName=${CONTROLPLANE_SUBDOMAIN_NAME} \
    keyVaultName=${AZURE_VAULT} \
    keyVaultRG=${VAULT_RG} \
```

## clean/delete deployment

use this to delete the keyvault policy and remove all deployed resources

```bash
az keyvault delete-policy --name ${AZURE_VAULT} --object-id $(az vm identity show --resource-group ${JUMPBOX_RG} --name ${JUMPBOX_NAME} --query principalId --output tsv)
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
```


