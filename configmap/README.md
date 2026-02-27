# 🛡️ SCONE ConfigMap Example: Secure Your Configurations in Kubernetes

This example walks you through how to securely manage and access configuration data in Kubernetes using a `ConfigMap` and a SCONE-enabled Rust application. You’ll start with a plain (unencrypted) deployment, then transition to a fully protected SCONE deployment.

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

First, we ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`.


```bash
pushd configmap
# ensure that the following is not set
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
```

The default values of several environment variables are defined in file `Values.yaml`.
`tplenv` asks you if all defaults are ok. It then sets the environment variables:

 - `$DEMO_IMAGE` - name of the native container image to deploy the application,
 - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image
 - `$IMAGE_PULL_SECRET_NAME` the name of the pull secret to pull this image (default is `sconeapps`).  For simplicity, we assume that we can use the same pull secret to run the native and the confidential workload. 
 - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1) 
 - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)
 - `$CAS_NAME` - The CAS name to use (e.g., `cas`) 
 - `$CVM_MODE` - If you want to have CVM mode, set to `--cvm`. For SGX, leave empty. 
 - `$SCONE_ENCLAVE` - In CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata-Pods (leave it empty). 

Program `tplenv` asks the user if our current (default) configuration stored in `Values.yaml`.
The user can modify the configuration if needed by setting the following variable to `--force`.
Replace the `--force` by `""` to only ask for variables that are not defined in the environment
or the Values.yaml file. Note that the `Values.yaml` file has priority over the environment variables.
If the user changes values, they are written to `Values.yaml`.

Ensure that we ask the user to confirm or modify all environment variables:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
```

`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`:

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

We assume that you need a pull secret to pull the native and the confidential container image. We first check if the pull secret is already set. If it is not set, we ask the user to input the necessary information to create the pull secret:

- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.
- `$REGISTRY_USER` - the login name of the user that pulls the container image.
- `$REGISTRY_TOKEN` - the token to pull the secret. See <https://sconedocs.github.io/registry/> for how to create this token.

Note that `tplenv` stores this information in file `Values.yaml`. 

```bash
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} not exist - creating now."
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
