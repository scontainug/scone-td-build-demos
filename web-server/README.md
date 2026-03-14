# Web Server Demo

## Introduction

This Rust application is a minimal web service built with [Axum](https://github.com/tokio-rs/axum). It is intentionally small and easy to follow.

[![Web-Server Example](../docs/web-server.gif)](../docs/web-server.mp4)

## Endpoints

- **Generate password (`/gen`)**
  - Generates a random alphanumeric password.
  - Example response:

  ```json
  {
    "password": "aBcD1234EeFgH5678"
  }
  ```

- **Print path (`/path`)**
  - Reads files from `/config` and returns file names and contents.
  - Example response:

  ```json
  {
    "name": "file1.txt",
    "content": "This is the content of file1.txt.\n..."
  }
  ```

- **Print environment variable (`/env/:env`)**
  - Returns the value of the requested environment variable.
  - Example response:

  ```json
  {
    "value": "your_env_value_here"
  }
  ```

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

## 3. Set Up Environment Variables

Assume you start in `scone-td-build-demos`, then switch to this demo:

```bash
# Enter `web-server` and remember the previous directory.
pushd web-server
# Remove `storage.json` if it exists.
rm storage.json || true
```

Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:

- `$IMAGE_NAME` - Name of the native `web-server` image
- `$DESTINATION_IMAGE_NAME` - Name of the confidential image
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)
- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)
- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)
- `$CAS_NAME` - CAS name (for example, `cas`)
- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX
- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Attest CAS before sending encrypted policies:

```bash
# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is ok if you first attested using *scone cas attest ..."
```

If attestation fails, review the output for detected issues and suggested tolerance flags.

Render the manifest template:

```bash
# Render the template with the selected values.
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml
```

## 4. Create a Pull Secret

If the pull secret does not exist yet, create it using registry credentials.

- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` - Registry login name
- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

## 5. Build and Register the Image

Build and push the native image:

```bash
# Build the container image.
docker build -t ${IMAGE_NAME} .
# Push the container image to the registry.
docker push ${IMAGE_NAME}
```

Generate a signing key for confidential binaries if needed:

```bash
# Check whether the signing key needs to be generated.
if [ ! -f identity.pem ]; then
  # Print a status message.
  echo "Generating identity.pem ..."
  # Generate the signing key for confidential binaries.
  openssl genrsa -3 -out identity.pem 3072
else
  # Print a status message.
  echo "identity.pem already exists."
fi
```

Register the image with `scone-td-build`:

```bash
# Register the image for confidential execution.
scone-td-build register \
  --protected-image ${IMAGE_NAME} \
  --unprotected-image ${IMAGE_NAME} \
  --destination-image ${DESTINATION_IMAGE_NAME} \
  --push \
  -s ./storage.json \
  --enforce /app/web-server \
  --version ${SCONE_RUNTIME_VERSION}
```

## 6. Test the Native Manifest (Optional)

Clean up previous runs first:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete deployment web-server || echo "ok - no web-server deployment yet"
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server --timeout=240s || echo "ok - no web-server deployment yet"
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-8000.pid) || true
```

Deploy and test:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifest.yaml
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# Start a local port-forward to the Kubernetes workload.
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
# Run the demo test script.
./test.sh

# Delete the Kubernetes resource if it exists.
kubectl delete -f manifest.yaml
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server --timeout=240s
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-8000.pid) || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid
```

## 7. Convert the Manifest

If you want to inspect registration details, see [register-image](../../../register-image.md).

```bash
# Convert the native manifest into a confidential manifest.
scone-td-build apply \
  -f manifest.yaml \
  -c ${CAS_NAME}.${CAS_NAMESPACE} \
  -s ./storage.json \
  --spol \
  --manifest-env SCONE_SYSLIBS=1 \
  --manifest-env SCONE_VERSION=1 \
  --session-env SCONE_VERSION=1 \
  --output-manifest-file manifest.sanitized.yaml \
  --version ${SCONE_RUNTIME_VERSION} -p
```

## 8. Deploy the Confidential Manifest

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifest.sanitized.yaml
```

For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.

## 9. Run the Demo

```bash
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# A ready pod does not always mean the port is immediately available.
# Wait briefly for the service to become reachable.
sleep 20
# Start a local port-forward to the Kubernetes workload.
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid
```

Send test requests:

```bash
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- curl http://localhost:8000/gen
# Run the demo test script.
./test.sh
```

## 10. Uninstall the Demo

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f manifest.sanitized.yaml
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-8000.pid) || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid
# Return to the previous working directory.
popd
```

This demo provides a simple but functional Rust web service that you can extend as needed.
