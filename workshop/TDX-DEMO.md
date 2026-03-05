# TDX Demo

This guide covers building the prerequisites and creating a 2-node TDX cluster on Azure with platform attestation.

The 2-node setup is used to demonstrate platform attestation, where KBS verifies that each node runs inside a genuine TDX VM before releasing secrets. If you do not need attestation for your demo, you can simplify by creating a single-node cluster with the `--no-attestation` flag.

## Prerequisites

- Rust toolchain (install via [rustup](https://rustup.rs/))
- Azure CLI (`az`) installed and configured
- `kubectl` installed
- Docker (for building the KBS image)
- An Azure subscription with quota for DC-series CVM VMs (DCesv5 or DCedsv5 for TDX)

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

## 1. Build the Custom CVM Image

TDX clusters require a custom CVM image with the `scone_enclave` kernel driver built into the kernel. This image is created once and reused across clusters.

### Clone the Required Repositories

```bash
git clone https://github.com/scontain-gmbh/kubectl-scone-azure.git
cd kubectl-scone-azure
git checkout laerson/workshop

git clone git@gitlab.scontain.com:sergey/cvm-kernel-module.git
cd cvm-kernel-module
git checkout sergei/in-tree
cd ..
```

### Run the Image Build Script

The build script compiles a custom linux-azure kernel with the `scone_enclave` driver, creates an Azure CVM from it, and publishes it as a gallery image:

```bash
./scripts/build-cvm-image.sh \
    --driver-source cvm-kernel-module/scone_enclave \
    --gallery-name sconeGallery \
    --resource-group <resource-group> \
    --subscription-id <subscription-id>
```

The script generates a signing keypair automatically. To reuse an existing keypair:

```bash
./scripts/build-cvm-image.sh \
    --driver-source cvm-kernel-module/scone_enclave \
    --signing-key kernel-signing.key \
    --signing-cert kernel-signing.der \
    --gallery-name sconeGallery \
    --resource-group <resource-group> \
    --subscription-id <subscription-id>
```

When the script finishes, it prints the gallery image ID. Save it for the next steps.

### Add the Image to Additional Regions

The gallery image is created in a single region. To deploy clusters in other regions, replicate it:

```bash
az sig image-version update \
    -g <resource-group> -r sconeGallery -i ubuntu-cvm-scone -e 1.0.0 \
    --target-regions "<region-1>" "<region-2>"
```

### Create the scone-config.json File

Create a configuration file referencing the gallery image:

```json
{
    "image": "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/galleries/sconeGallery/images/ubuntu-cvm-scone/versions/1.0.0"
}
```

For full details on the image build pipeline, see [BUILD-CVM-IMAGE.md](https://github.com/scontain-gmbh/kubectl-scone-azure/blob/laerson/workshop/docs/BUILD-CVM-IMAGE.md).

## 2. Build the KBS Image

The Key Broker Service (KBS) handles platform attestation. It verifies that cluster nodes run inside genuine TDX VMs before releasing secrets.

### Clone and Build

```bash
git clone https://github.com/scontain-gmbh/trustee.git
cd trustee

DOCKER_BUILDKIT=1 docker build -t kbs:azure-vtpm . -f kbs/docker/Dockerfile
```

### Push to a Registry

```bash
docker tag kbs:azure-vtpm ghcr.io/<your-org>/kbs:latest
docker push ghcr.io/<your-org>/kbs:latest
```

### Verify the Build

```bash
docker run -d --name kbs-test -p 8080:8080 kbs:azure-vtpm
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/kbs/v0/
docker rm -f kbs-test
```

A 200 response confirms the image is working.

For full details on the KBS build, see [BUILD-KBS.md](https://github.com/scontain-gmbh/kubectl-scone-azure/blob/laerson/workshop/docs/BUILD-KBS.md).

## 3. Build kubectl-scone-azure

```bash
cd kubectl-scone-azure
cargo build --release
```

The binary is at `target/release/kubectl-scone_azure`.

## 4. Create the TDX Cluster

### Environment Variables

```bash
export AZURE_CREDENTIALS_PATH=/path/to/az-credentials.json
export AZURE_RESOURCE_GROUP=my-resource-group  # optional, auto-generated if omitted
```

### Create a 2-Node Cluster with Attestation

```bash
cargo run --release -- create --tdx \
  --node-count 2 \
  --scone-config ./scone-config.json \
  --deploy-kbs \
  --kbs-image ghcr.io/<your-org>/kbs:latest \
  --kube-config ./kubeconfig-tdx.yaml \
  --credentials "$AZURE_CREDENTIALS_PATH" \
  --rg "$AZURE_RESOURCE_GROUP" \
  -v
```

This provisions 2 Azure CVM nodes running inside TDX VMs, deploys KBS to the control plane, and performs platform attestation on each worker node. The tool automatically selects the cheapest available TDX VM size and region that has quota.

> **Note:** Attestation failures can be transient. Azure VMs may land on physical hosts whose TDX platform configuration (FMSPC) is not yet recognized by the KBS attestation verifier, causing an `RCAR handshake Attest failed` error. Retrying the cluster creation typically resolves this, as the new VM is placed on a different host. If attestation is not required for your use case, use `--no-attestation` to skip it entirely.

### Alternative: Single Node Without Attestation

If you do not need to demonstrate platform attestation, create a simpler single-node cluster:

```bash
cargo run --release -- create --tdx \
  --node-count 1 \
  --scone-config ./scone-config.json \
  --no-attestation \
  --kube-config ./kubeconfig-tdx.yaml \
  --credentials "$AZURE_CREDENTIALS_PATH" \
  --rg "$AZURE_RESOURCE_GROUP" \
  -v
```

### Verify the Cluster

```bash
export KUBECONFIG=./kubeconfig-tdx.yaml
kubectl get nodes
```

Both nodes should show `Ready` status. To verify the custom kernel driver is available:

```bash
kubectl debug node/<node-name> -it --image=ubuntu -- \
    ls -la /dev/scone_enclave
```

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
export KUBECONFIG=../kubeconfig-tdx.yaml
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

### 2. Connect to the SGX Cluster's CAS

CAS cannot run on TDX nodes, so we reuse the CAS instance from the SGX cluster. This requires exposing CAS on the SGX cluster via a LoadBalancer and creating a proxy service in the TDX cluster.

> **Note:** The CAS service in the SGX cluster is managed by the SCONE operator, so we cannot change its type directly. Instead, we create a separate LoadBalancer service that targets the same CAS pods.

**On the SGX cluster**, create a LoadBalancer service for CAS:

```bash
kubectl --kubeconfig <path-to-sgx-kubeconfig> apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: cas-external
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: cas
    app.kubernetes.io/instance: cas
    app.kubernetes.io/name: cas
  ports:
    - name: client
      port: 8081
      targetPort: client
    - name: enclave
      port: 18765
      targetPort: enclave
EOF
```

Wait for the external IP to be assigned:

```bash
kubectl --kubeconfig <path-to-sgx-kubeconfig> get svc cas-external -n default -w
```

Once the `EXTERNAL-IP` column shows an IP address (not `<pending>`), save it:

```bash
export CAS_EXTERNAL_IP=$(kubectl --kubeconfig <path-to-sgx-kubeconfig> \
    get svc cas-external -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "CAS external IP: $CAS_EXTERNAL_IP"
```

**On the TDX cluster**, create a Service and Endpoints that point to the SGX cluster's CAS. This makes `cas.default` resolve to the external CAS in the TDX cluster:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: cas
  namespace: default
spec:
  ports:
    - name: client
      port: 8081
      targetPort: 8081
    - name: enclave
      port: 18765
      targetPort: 18765
---
apiVersion: v1
kind: Endpoints
metadata:
  name: cas
  namespace: default
subsets:
  - addresses:
      - ip: "${CAS_EXTERNAL_IP}"
    ports:
      - name: client
        port: 8081
      - name: enclave
        port: 18765
EOF
```

Verify the TDX cluster can reach CAS:

```bash
scone cas attest ${CAS_EXTERNAL_IP}:8081 \
    --accept-configuration-needed \
    --accept-group-out-of-date \
    --accept-sw-hardening-needed \
    --mrsigner 195e5a6df987d6a515dd083750c1ea352283f8364d3ec9142b0d593988c6ed2d \
    --isvprodid 41316 \
    --isvsvn 5
```

## Run the Demos

Clone the demos repository and configure the image registries.

### 3. Clone the Demos Repository

```bash
git clone https://github.com/scontain/scone-td-build-demos.git
cd scone-td-build-demos
git checkout laerson/workshop
```

### 4. Configure Image Registries

Each demo has a `Values.yaml` file that controls where container images are pushed and pulled. The demos build container images and push them to a registry, so you need **write (push) access** to the registry you configure.

Update the following files with your registry details:

- `hello-world/Values.yaml`
- `configmap/Values.yaml`
- `web-server/Values.yaml`

The key variables to configure are:

| Variable | Description |
|---|---|
| `IMAGE_NAME` / `DEMO_IMAGE` | Native container image URL (built and pushed by the demo) |
| `DESTINATION_IMAGE_NAME` | Protected (sconified) container image URL (pushed by `scone-td-build`) |
| `IMAGE_PULL_SECRET_NAME` | Kubernetes pull secret name for the registry |
| `REGISTRY` | Docker registry hostname (e.g., `ghcr.io`, `docker.io`) |
| `REGISTRY_USER` | Your username for the registry |
| `REGISTRY_TOKEN` | Your access token for the registry |

For TDX mode, also set `CVM_MODE` and `SCONE_ENCLAVE` in each `Values.yaml`:

```yaml
environment:
  CVM_MODE: '--cvm'
  SCONE_ENCLAVE: '--scone-enclave'
```

> **Note:** `CAS_NAME`, `CAS_NAMESPACE`, and `SCONE_VERSION` can typically be left at their defaults.

### 5. Run All Demos

```bash
./scripts/run-all-cvm-scripts.sh
```

This runs the hello-world, configmap, and web-server demos sequentially in CVM mode. Each demo builds a native application, sconifies it with `scone-td-build`, and deploys it to the cluster.

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
