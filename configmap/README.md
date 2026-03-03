# 🛡️ SCONE ConfigMap Example: Secure Your Configurations in Kubernetes

This example walks you through how to securely manage and access configuration data in Kubernetes using a `ConfigMap` and a SCONE-enabled Rust application. You’ll start with a plain (unencrypted) deployment, then transition to a fully protected SCONE deployment.

![ConfigMap Example](../docs/configmap.gif)

______________________________________________________________________

### 1. Prerequisites

- A token for accessing `scone.cloud` images on registry.scontain.com
- A Kubernetes cluster
- The Kubernetes command line tool (`kubectl`)
- Rust `cargo` is installed (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

#### 2. Set up the environment

Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).

______________________________________________________________________

#### 3. Setting up the Environment Variables

First, we ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.


```bash
pushd configmap
```

The default values of several environment variables are defined in file `Values.yaml`.
`tplenv` asks whether all defaults are okay. It then sets the environment variables:

 - `$DEMO_IMAGE` - name of the native container image to deploy the application,
 - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image
 - `$IMAGE_PULL_SECRET_NAME` - the name of the pull secret used to pull this image (default: `sconeapps`). For simplicity, we assume we can use the same pull secret for both the native and confidential workloads.
 - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1) 
 - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)
 - `$CAS_NAME` - The CAS name to use (e.g., `cas`) 
 - `$CVM_MODE` - if you want CVM mode, set it to `--cvm`. For SGX, leave it empty.
 - `$SCONE_ENCLAVE` - in CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata Pods (leave it empty).

Program `tplenv` asks the user whether to keep the current (default) configuration stored in `Values.yaml`.
Note that `Values.yaml` has priority over environment variables.
If the user changes values, they are written to `Values.yaml`.

`tplenv` will now ask for all environment variables described in `environment-variables.md`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file  --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
```

## 🧱 4. Build the Native Rust Image

This step builds a native version of the image to validate behavior before enforcing protection with SCONE.

```bash
pushd folder-reader
docker build -t ${DEMO_IMAGE} .
docker push ${DEMO_IMAGE}

popd
```

______________________________________________________________________

## 🧩 Step 5: Render the Manifest

To render the manifests, we first need to define the signer key used to sign policies:

```bash
export SIGNER="$(scone self show-session-signing-key)"
```

We then instantiate the manifest templates:

```bash
tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml  --indent
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml  --indent
```

> Make sure the image name was correctly substituted in the manifest.native.yaml file before applying it with kubectl.

______________________________________________________________________

## 🔑 6. Add Docker Registry Secret to Kubernetes

We assume you need a pull secret to pull both the native and confidential container images. First, we check whether the pull secret is already set. If it is not, we ask the user for the information needed to create it:

- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.
- `$REGISTRY_USER` - the login name of the user that pulls the container image.
- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.

Note that `tplenv` stores this information in `Values.yaml`.

```bash
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # ask user for the credentials for accessing the registry
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

______________________________________________________________________

## 🧪 7. Deploy the Native App [OPTIONAL]

```bash
kubectl apply -f manifests/manifest.yaml

retry-spinner -- kubectl logs job/my-rust-app -c reader-1
retry-spinner -- kubectl logs job/my-rust-app -c reader-2

# Clean up native app
kubectl delete -f manifests/manifest.yaml
```

✅ Your containers should log content from their mounted ConfigMap files.

______________________________________________________________________

## 🧩 8. Prepare and Apply the SCONE Manifest

```bash
scone-td-build from -y manifests/scone.yaml
```

This step:

- Generates a SCONE session
- Attaches it to your manifest
- Produces a new `manifests/manifest.prod.sanitized.yaml` with the necessary information to use the created session

______________________________________________________________________

## 🚀 9. Deploy the SCONE-Protected App

```bash
kubectl apply -f manifests/manifest.prod.sanitized.yaml
```

______________________________________________________________________

## 📜 10. View Logs

Check that SCONE-protected containers can access the expected ConfigMap data:

```bash
retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow
retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow
```

______________________________________________________________________

## 🧹 11. Clean Up

```bash
kubectl delete -f manifests/manifest.prod.sanitized.yaml
```
