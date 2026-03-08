# Web Server Demo

## Introduction

This Rust application is a minimal web service built with [Axum](https://github.com/tokio-rs/axum). It is intentionally small and easy to follow.

![Web-Server Example](../docs/web-server.gif)

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
pushd web-server
```

Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:

- `$IMAGE_NAME` - Name of the native `web-server` image
- `$DESTINATION_IMAGE_NAME` - Name of the confidential image
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)
- `$SCONE_VERSION` - SCONE version to use (for example, `7.0.0-alpha.1`)
- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)
- `$CAS_NAME` - CAS name (for example, `cas`)
- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX
- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods

```bash
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Attest CAS before sending encrypted policies:

```bash
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S
```

If attestation fails, review the output for detected issues and suggested tolerance flags.

Render the manifest template:

```bash
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml
```

## 4. Build and Register the Image

Build and push the native image:

```bash
docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}
```

Generate a signing key for confidential binaries if needed:

```bash
if [ ! -f identity.pem ]; then
  echo "Generating identity.pem ..."
  openssl genrsa -3 -out identity.pem 3072
else
  echo "identity.pem already exists."
fi
```

Register the image with `scone-td-build`:

```bash
scone-td-build register \
  --protected-image ${IMAGE_NAME} \
  --unprotected-image ${IMAGE_NAME} \
  --destination-image ${DESTINATION_IMAGE_NAME} \
  --push \
  -s ./storage.json \
  --enforce /app/web-server \
  --version ${SCONE_VERSION}
```

## 5. Test the Native Manifest (Optional)

Clean up previous runs first:

```bash
kubectl delete deployment web-server || echo "ok - no web-server deployment yet"
kubectl wait --for=delete pod -l app=web-server --timeout=240s || echo "ok - no web-server deployment yet"
kill $(cat /tmp/pf-8000.pid) || true
```

Deploy and test:

```bash
kubectl apply -f manifest.yaml
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid

retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
./test.sh

kubectl delete -f manifest.yaml
kubectl wait --for=delete pod -l app=web-server --timeout=240s
kill $(cat /tmp/pf-8000.pid) || true
rm /tmp/pf-8000.pid
```

## 6. Convert the Manifest

If you want to inspect registration details, see [register-image](../../../register-image.md).

```bash
scone-td-build apply \
  -f manifest.yaml \
  -c ${CAS_NAME}.${CAS_NAMESPACE} \
  -s ./storage.json \
  --manifest-env SCONE_SYSLIBS=1 \
  --manifest-env SCONE_VERSION=1 \
  --session-env SCONE_VERSION=1 \
  --version ${SCONE_VERSION} -p
```

## 7. Deploy the Confidential Manifest

```bash
kubectl apply -f manifest.cleaned.yaml
```

For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.

## 8. Run the Demo

```bash
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# A ready pod does not always mean the port is immediately available.
sleep 20
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid
```

Send test requests:

```bash
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
retry-spinner -- curl http://localhost:8000/gen
./test.sh
```

## 9. Uninstall the Demo

```bash
kubectl delete -f manifest.cleaned.yaml
kill $(cat /tmp/pf-8000.pid) || true
rm /tmp/pf-8000.pid
popd
```

This demo provides a simple but functional Rust web service that you can extend as needed.
