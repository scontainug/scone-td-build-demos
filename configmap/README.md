# SCONE ConfigMap Example: Secure Configuration Data in Kubernetes

This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a SCONE-enabled Rust application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.


[![ConfigMap Example](../docs/configmap.gif)](../docs/configmap.mp4)

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

## 3. Set Up Environment Variables

Assume you start in `scone-td-build-demos` and switch into this demo directory:

```bash
pushd configmap
rm -f configmap-example.json || true
```

Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:

- `$DEMO_IMAGE` - Name of the native image to deploy
- `$DESTINATION_IMAGE_NAME` - Name of the confidential image
- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)
- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)
- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)
- `$CAS_NAME` - CAS name (for example, `cas`)
- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX
- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods

Set `SIGNER` for policy signing:

```bash
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

## 4. Build the Native Rust Image

```bash
pushd folder-reader
docker build -t ${DEMO_IMAGE} .
docker push ${DEMO_IMAGE}
popd
```

## 5. Render the Manifests

```bash
tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml --indent
```

Before applying, confirm that image values were substituted correctly.

## 6. Add a Docker Registry Secret

If you need a pull secret for native and confidential images, create it when missing.

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

## 7. Deploy the Native App (Optional)

```bash
kubectl apply -f manifests/manifest.yaml
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -c reader-1
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -c reader-2

# Clean up native app
kubectl delete -f manifests/manifest.yaml
```

Your containers should print content from the mounted ConfigMap files.

## 8. Prepare and Apply the SCONE Manifest

```bash
scone-td-build from -y manifests/scone.yaml
```

This command:

- Generates a SCONE session
- Attaches the session to your manifest
- Produces `manifests/manifest.prod.sanitized.yaml`

## 9. Deploy the SCONE-Protected App

```bash
kubectl apply -f manifests/manifest.prod.sanitized.yaml
```

## 10. View Logs

```bash
retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow
retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow
```

## 11. Clean Up

```bash
kubectl delete -f manifests/manifest.prod.sanitized.yaml
popd
```
