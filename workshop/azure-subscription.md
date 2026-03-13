This file defines the Azure subscription variables used by `kubectl-scone-azure` to provision clusters.

- `$AZURE_CREDENTIALS_PATH` - path to the Azure service principal credentials JSON file (created via `az ad sp create-for-rbac`).
- `$AZURE_RESOURCE_GROUP` - Azure resource group name for the cluster. If left empty, one will be auto-generated.