#!/usr/bin/env bash
# One-time setup: creates the Entra ID app registration + federated credential
# for GitHub OIDC login, assigns it Reader on rg-app-prod, and pushes a
# dedicated SSH deploy key onto both VMs (no network SSH required for this —
# az vm user update goes through the Azure control plane, not the network).
#
# Run this once from a machine with Azure CLI logged in (az login).
# Fill in the variables below first.

set -euo pipefail

# ---- EDIT THESE ----
GITHUB_ORG="your-github-username-or-org"
GITHUB_REPO="your-repo-name"
RESOURCE_GROUP="rg-app-prod"
VM1_NAME="vm-app-01"
VM2_NAME="vm-app-02"
VM_USER="azureuser"
APP_NAME="gh-actions-deploy-cicd"
# ---------------------

echo "== 1. Create the Entra ID app registration =="
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
echo "App (client) ID: $APP_ID"

echo "== 2. Create the service principal for the app =="
az ad sp create --id "$APP_ID" >/dev/null

echo "== 3. Add the federated credential trusting GitHub Actions on main =="
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"gh-main-deploy\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

echo "== 4. Assign Reader on the resource group (needed for Bastion tunnel + az vm show) =="
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
az role assignment create \
  --assignee "$APP_ID" \
  --role "Reader" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

echo "== 5. Generate a dedicated SSH key pair for the pipeline =="
ssh-keygen -t ed25519 -f ./github-deploy-key -C "github-actions-deploy" -N ""

echo "== 6. Push the public key onto both VMs via the Azure control plane =="
for VM in "$VM1_NAME" "$VM2_NAME"; do
  az vm user update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM" \
    --username "$VM_USER" \
    --ssh-key-value "$(cat ./github-deploy-key.pub)"
  echo "  -> key installed on $VM"
done

echo ""
echo "============================================================"
echo "Done. Now add these as GitHub repo secrets"
echo "(Settings > Secrets and variables > Actions > New repository secret):"
echo ""
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "  VM_SSH_PRIVATE_KEY    = <paste the full contents of ./github-deploy-key>"
echo ""
echo "IMPORTANT: delete ./github-deploy-key and ./github-deploy-key.pub"
echo "from this machine once you've copied the private key into GitHub secrets."
echo "============================================================"
