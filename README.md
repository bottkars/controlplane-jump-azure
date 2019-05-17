# controlplane-jump-azure

This Repo set´s up the "Control Plane" for Pivotal Platform Automation from a JumpHost on Azure

in Addition to the [Documentation](http://docs.pivotal.io/platform-automation/), Azure KeyVault an System managed identities are used to
Store Secrets and Credentials

You will need

- An Azure Subscription
- A Service Principal
- A Pivotal Network Refresh Token
- Access to Pivotal Automation Control Plane Components on Pivnet
- local machine with azure az cli
- a Hosted (Sub)domain for the DNS Zone for Control Plane ( e.g. Google Domain )

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

#### create the KeyVault

```bash
AZURE_VAULT=<your vaultname, name must be unique fro AZURE_VAULT.vault.azure.com>
VAULT_RG=<your Vault Resource Group>
LOCATION=<azure location, e.g. westus, westeurope>
## Create RG to set your KeyVault
az group create --name ${VAULT_RG} --location ${LOCATION}
## Create keyVault
az keyvault create --name ${AZURE_VAULT} --resource-group ${VAULT_RG} --location ${LOCATION}
```

#### create SP and assign values to the vault  secrets

```bash
## Set temporary Variables
PIVNET_UAA_TOKEN=<your pivnet refresh token>
SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ServicePrincipalforControlPlane --output json)
## SET the Following Secrets from the temporary Variables
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "AZURECLIENTID" --value $(echo $SERVICE_PRINCIPAL | jq -r .appId) --output none
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "AZURETENANTID" --value $(echo $SERVICE_PRINCIPAL | jq -r .tenant) --output none
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "AZURECLIENTSECRET" --value $(echo $SERVICE_PRINCIPAL | jq -r .password) --output none
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "PIVNETUAATOKEN" --value ${PIVNET_UAA_TOKEN} --output none
## unset the temporary variables
unset SERVICE_PRINCIPAL
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

you might also add some optional Parameters to override default values:

```bash
CONTROLPLANE_AUTOPILOT=<TRUE or FALSE> to start automatic install of Control Plane from BosH Release
USE_SELF_CERTS=<TRUE or FALSE> set tu False to use Let´s Encrypt
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
[image](https://user-images.githubusercontent.com/8255007/57944340-fcbba080-78d6-11e9-89e4-bf771c7288ee.png)

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
    keyVaultRG=${VAULT_RG}
```

### deploy all things using standard Parameters

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
    keyVaultRG=${VAULT_RG}
```

### deploy all using custom Parameters

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
    CONTROLPLANEAutopilot=${CONTROLPLANE_AUTOPILOT} \
    useSelfCerts=${USE_SELF_CERTS} \
    keyVaultName=${AZURE_VAULT} \
    keyVaultRG=${VAULT_RG}
```

## after Provisioning finished

the base provisioning of the VM takes 5 to 10 Minutes on Azure.
when provisioning is done, ssh into the Jumphost:

```Bash
ssh -i ~/${JUMPBOX_NAME} ${ADMIN_USERNAME}@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

tail the installation log in the root directory

```bash
tail -f install.log
```

the log file will log the base provisioning
once finisehd, the Opsman Bosh Director and Control Plane Installation Starts.
the log will instruct you to

```bash
tail -f /home/bottkars/conductor/logs/om_init.sh.*.log
```

you will get login credential for you controlplane at the end of he log, or by using:
from the jumphost
```bash
source .env.sh
eval "$(om --skip-ssl-validation --env om_meetup.env bosh-env --ssh-private-key opsman)"
credhub get -n $(credhub find | grep uaa_users_admin | awk '{print $3}')
```


## clean/delete deployment

use this to delete the keyvault policy and remove all deployed resources

```bash
az keyvault delete-policy --name ${AZURE_VAULT} --object-id $(az vm identity show --resource-group ${JUMPBOX_RG} --name controlplanejumphost --query principalId --output tsv)
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
```

## TBD

- deployment script for control plane is in an early stage and does no error checkings
- documentation
- Azure Zones vs Aset Selector ( currently deployed in zones)
- custom vm types
