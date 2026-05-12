# SCONE: Image Signing

This example shows how to sign and encrypt a confidential container image using a Sigstore private
key, then verify the signature before deploying it to Kubernetes.

Image signing provides supply chain integrity: only images signed with a trusted private key pass
verification. Combined with SCONE encryption, the image layers are also protected at rest in the
registry.

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX or CVM support
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- `skopeo` for image inspection and signature verification
- `openssl` for signing key generation

Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:

- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)
- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)

## 2. Set Up Environment Variables

We assume you start in `scone-td-build-demos`:

```bash
# Enter `image-signing` and remember the previous directory.
pushd image-signing
# Remove `storage.json` if it exists.
rm -f storage.json || true
```

This example uses the following variables.

For the native deployment:

- `$IMAGE_NAME` - Name of the native container image
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name for this image (default: `sconeapps`)

For the signing and confidential deployment:

- `$DESTINATION_IMAGE_NAME` - Name of the SCONE-protected image
- `$REPO_CREDENTIALS` - Path to Docker credentials file used by the signing push (default: `~/.docker/config.json`)
- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)
- `$CAS_NAMESPACE` - CAS Kubernetes namespace (for example, `default`)
- `$CAS_NAME` - CAS Kubernetes name (for example, `cas`)
- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX
- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods
- `$NAMESPACE` - Kubernetes namespace where the demo runs (default: `default`)

Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
```

Generate the job manifest with the selected image and pull-secret values:

```bash
# Render the template with the selected values.
tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml
```

## 3. Deploy Key Management Infrastructure

The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in
the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.

```bash
# Deploy the Key Broker Service.
kubectl apply -f k8s/kbs.yaml
# Deploy the key provider.
kubectl apply -f k8s/key-provider.yaml
# Wait for KBS to be ready.
kubectl wait --for=condition=available deployment/kbs -n trustee --timeout=120s
# Wait for the key provider to be ready.
kubectl wait --for=condition=available deployment/keyprovider -n trustee --timeout=120s
# Forward the key provider port to localhost so skopeo can reach it.
kubectl port-forward -n trustee svc/keyprovider 50000:50000 &
export PORT_FORWARD_PID=$!
# Give the port-forward a moment to establish the connection.
sleep 3
```

## 4. Generate Signing Keys

Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed
to verify signatures without exposing the private key.

```bash
# Generate the Ed25519 signing private key.
openssl genpkey -algorithm ed25519 -out ./config/image-signing-key.pem
# Extract the corresponding public key.
openssl pkey -in ./config/image-signing-key.pem -pubout -out ./config/public.pub
```

Configure the registry to store signatures as sigstore OCI attachments:

```bash
# Configure sigstore attachments for the registry.
sudo mkdir -p /etc/containers/registries.d
cat <<EOF | sudo tee /etc/containers/registries.d/default.yaml > /dev/null
docker:
    ${REGISTRY}:
        use-sigstore-attachments: true
EOF
```

## 5. Build the Native Container Image

Create the Rust project (or reuse an existing one):

```bash
# Create the Rust project in `hello-world` if it does not already exist.
cargo new hello-world || echo "hello-world already exists - using existing one"
```

Build and push the image:

```bash
# Build the container image.
docker build -t $IMAGE_NAME .
# Push the container image to the registry.
docker push $IMAGE_NAME
```

## 6. Create a Pull Secret

If the pull secret does not exist yet, create it using registry credentials.

- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` - Registry login name
- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
# Check whether the pull secret already exists.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Load environment variables from the tplenv definition file.
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

## 7. Run the Native Application

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f manifest.job.yaml -n ${NAMESPACE}
```

Wait for completion and stream logs:

```bash
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
```

Clean up:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
```

## 8. Attest SCONE CAS

Before sending encrypted policies to CAS, attest CAS via the Kubernetes API:

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."
```

If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.

## 9. Register and Sign the Confidential Image

The `--signing-key` flag activates the encrypted-image flow: `scone-td-build` sconifies the image,
then uses `skopeo` to encrypt the layers with the attestation-agent key provider and embed a
Sigstore signature. The result is pushed to `${DESTINATION_IMAGE_NAME}-encrypted`.

```bash
# Register, sign, and encrypt the confidential image.
OCICRYPT_KEYPROVIDER_CONFIG=./config/ocicrypt.conf \
  scone-td-build register \
    --protected-image $IMAGE_NAME \
    --unprotected-image rust:latest \
    --manifest-env SCONE_PRODUCTION=0 \
    -s ./storage.json \
    --destination-image ${DESTINATION_IMAGE_NAME} \
    --signing-key ./config/image-signing-key.pem \
    --signing-passphrase-file ./config/empty-passphrase.txt \
    --repo-credentials ${REPO_CREDENTIALS} \
    --version ${SCONE_RUNTIME_VERSION} \
    ${CVM_MODE}
```

## 10. Verify Image Signature

Inspect the signed and encrypted image to confirm the Sigstore signature is attached:

```bash
# Inspect the signed and encrypted image.
skopeo inspect docker://${DESTINATION_IMAGE_NAME}-encrypted
```

## 11. Transform the Kubernetes Manifest

Convert the native manifest into a sanitized confidential manifest:

```bash
# Convert the native manifest into a confidential manifest.
scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --manifest-env SCONE_HEAP=1G --spol --manifest-env SCONE_VERSION=1 --output-manifest-file manifest.job.sanitized.yaml ${CVM_MODE} ${SCONE_ENCLAVE}
```

Update the manifest to reference the signed and encrypted image:

```bash
# Replace the protected image reference with the signed and encrypted variant.
sed "s|image: ${DESTINATION_IMAGE_NAME}|image: ${DESTINATION_IMAGE_NAME}-encrypted|g" manifest.job.sanitized.yaml > manifest.job.signed.yaml
```

## 12. Deploy the Signed Confidential Application

```bash
# Apply the signed confidential manifest.
kubectl apply -f manifest.job.signed.yaml -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
```

## 13. Uninstall `image-signing`

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE} || true
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
# Stop the key provider port-forward.
kill ${PORT_FORWARD_PID} 2>/dev/null || true
# Delete the key provider.
kubectl delete -f k8s/key-provider.yaml
# Delete the Key Broker Service.
kubectl delete -f k8s/kbs.yaml
# Return to the previous working directory.
popd
```

## Automation

You can run this workflow with:

```
./scripts/image-signing.sh
```

It asks for user input unless you set:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
```

This uses values from `image-signing/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.

If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/image-signing.sh`.
