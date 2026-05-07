# SCONE: Hello World

[![Hello World Example](../docs/hello-world.gif)](../docs/hello-world.mp4)

This example shows how to build a simple cloud-native `hello-world` application in Rust, run it natively in Kubernetes, and then deploy a confidential version with SCONE.

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster with SGX or CVM support
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:

- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)
- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)

## 2. Set Up Environment Variables

We assume you start in `scone-td-build-demos`:

```bash
# Enter `hello-world` and remember the previous directory.
pushd hello-world
# Remove `storage.json` if it exists.
rm -f storage.json || true
```

This example uses the following variables.

For the native deployment:

- `$IMAGE_NAME` - Name of the native container image for `hello-world`
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name for this image (default: `sconeapps`)

For the confidential deployment:

- `$DESTINATION_IMAGE_NAME` - Name of the confidential image
- `$SCONE_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)
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

## 3. Build the Native Container Image

Create the Rust project (or reuse an existing one):

```bash
# Create the Rust project in `hello-world` if it does not already exist.
cargo new hello-world || echo "Hello World already exists - using existing one"
```

Build and push the image:

```bash
# Build the container image.
docker build -t $IMAGE_NAME .
# Push the container image to the registry.
docker push $IMAGE_NAME
```

## 4. Create a Pull Secret

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

## 5. Run the Native Hello-World Application

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f manifest.job.yaml -n ${NAMESPACE}
```

Wait for completion and stream logs:

```bash
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/hello-world -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
```

Clean up:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s
```

## 6. Attest SCONE CAS

Before sending encrypted policies to CAS, attest CAS via the Kubernetes API:

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."
```

If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.

## 7. Register the Confidential Image

Register the image for confidential execution:

```bash
# Register the image for confidential execution.
scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_RUNTIME_VERSION} ${CVM_MODE}
```

This creates a protected image (or uses `--destination-image` if provided) and decouples your deployment from upstream image changes.

## 8. Transform the Kubernetes Manifest

Convert the native manifest into a sanitized confidential manifest:

```bash
# Convert the native manifest into a confidential manifest.
scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --manifest-env SCONE_HEAP=1G --spol --manifest-env SCONE_VERSION=1 --output-manifest-file manifest.job.sanitized.yaml --version ${SCONE_RUNTIME_VERSION} ${CVM_MODE} ${SCONE_ENCLAVE}
```

## 9. Deploy the Confidential Manifest

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifest.job.sanitized.yaml -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/hello-world -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/hello-world -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
```

## 10. Uninstall `hello-world`

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete job hello-world -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=hello-world -n ${NAMESPACE} --timeout=300s
# Return to the previous working directory.
popd
```

## Automation

You can run this workflow with:

```
./scripts/hello-world.sh
```

It asks for user input unless you set:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
```

This uses values from `hello-world/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.

If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.
