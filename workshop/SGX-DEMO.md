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

## Deploy the SCONE Platform

Clone the SCONE deployment repository and move into it:

```bash
git clone https://github.com/laerson/scone.git
cd scone
git checkout laerson/workshop
```

Set the required environment variables:

```bash
export SCONE_VERSION="7.0.0-alpha.1"
export KUBECONFIG=../kubeconfig-sgx.yaml
export SCONE_REGISTRY_USERNAME="<your-registry-username>"
export SCONE_REGISTRY_ACCESS_TOKEN="<your-registry-access-token>"
export SCONE_REGISTRY_EMAIL="<your-email>"
export SGX_TOLERATIONS="--accept-configuration-needed --accept-group-out-of-date --accept-sw-hardening-needed --isvprodid 41316 --isvsvn 5 --mrsigner 195e5a6df987d6a515dd083750c1ea352283f8364d3ec9142b0d593988c6ed2d"
```

### 1. Install Prerequisites

Install required tools (cosign, kubectl, yq, etc.) and the SCONE CLI:

```bash
./scripts/prerequisite_check.sh
```

### 2. Install the SCONE Operator

Deploy the SCONE operator, LAS, and SGX plugin to the cluster:

```bash
./scripts/reconcile_scone_operator.sh
```

### 3. Install CAS

Set the CAS name and namespace, then deploy the Certificate Authority Service:

```bash
export CAS="cas"
export CAS_NAMESPACE="default"
./scripts/install_cas.sh
```

### 4. Deploy the SCONE CLI Pod

Deploy the SCONE toolbox pod to the cluster for running confidential computing transformations. The script will automatically drop you into the toolbox shell once the pod is ready:

```bash
./scripts/k8s_cli.sh
```

To re-enter the toolbox shell later:

```bash
kubectl exec -n scone-tools -it deploy/scone-toolbox -c scone-toolbox -- bash
```

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