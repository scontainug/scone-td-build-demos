# SGX Demo

This guide covers building `kubectl-scone-azure` from source and creating a 3-node SGX cluster on Azure.

## Prerequisites

- Rust toolchain (install via [rustup](https://rustup.rs/))
- Azure CLI (`az`) installed and configured
- `kubectl` installed
- An Azure subscription with quota for DC-series VMs (DCsv2, DCsv3, or DCdsv3)

## Azure Credentials

Create a service principal with Contributor role:

```bash
az ad sp create-for-rbac --name "scone-azure-sp" --role Contributor \
  --scopes /subscriptions/<subscription-id> --sdk-auth > az-credentials.json
```

This produces a JSON file with the following structure:

```json
{
  "tenantId": "your-tenant-id",
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id"
}
```

## Build

Clone and build the tool:

```bash
git clone https://github.com/scontain-gmbh/kubectl-scone-azure.git
cd kubectl-scone-azure
git checkout laerson/workshop
cargo build --release
```

The binary is at `target/release/kubectl-scone_azure`.

## Environment Variables

Set the path to your Azure credentials file:

```bash
export AZURE_CREDENTIALS_PATH=/path/to/az-credentials.json
```

Optionally, set a resource group name (one will be auto-generated if omitted):

```bash
export AZURE_RESOURCE_GROUP=my-resource-group
```

## Create the SGX Cluster

Create a 3-node SGX cluster:

```bash
cargo run --release -- create --sgx \
  --node-count 3 \
  --kube-config ./kubeconfig-sgx.yaml \
  --credentials "$AZURE_CREDENTIALS_PATH" \
  --rg "$AZURE_RESOURCE_GROUP" \
  -v
```

This provisions an AKS cluster with DC-series VMs (SGX-capable nodes) and the
confidential computing addon. The tool automatically selects the cheapest
available VM size and region that has quota.

Once complete, verify the cluster:

```bash
export KUBECONFIG=./kubeconfig-sgx.yaml
kubectl get nodes
```

All 3 nodes should show `Ready` status.

## Cleanup

Delete the cluster when done:

```bash
cargo run --release -- delete \
  --cluster-name <cluster-name> \
  --rg "$AZURE_RESOURCE_GROUP" \
  --credentials "$AZURE_CREDENTIALS_PATH" \
  -v
```

Replace `<cluster-name>` with the name shown during creation (e.g., `scone-9cc7dd39`).