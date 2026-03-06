#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# 🛡️ SCONE ConfigMap Example: Secure Your Configurations in Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This example walks you through how to securely manage and access configuration data in Kubernetes using a `ConfigMap` and a SCONE-enabled Rust application. You’ll start with a plain (unencrypted) deployment, then transition to a fully protected SCONE deployment.'
printf '%s\n' ''
printf '%s\n' '![ConfigMap Example](../docs/configmap.gif)'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '### 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on registry.scontain.com'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` is installed (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' '#### 2. Set up the environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '#### 3. Setting up the Environment Variables'
printf '%s\n' ''
printf '%s\n' 'First, we ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.'
printf '%s\n' ''
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'pushd configmap'
printf "${RESET}"

pushd configmap

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'The default values of several environment variables are defined in file `Values.yaml`.'
printf '%s\n' '`tplenv` asks whether all defaults are okay. It then sets the environment variables:'
printf '%s\n' ''
printf '%s\n' ' - `$DEMO_IMAGE` - name of the native container image to deploy the application,'
printf '%s\n' ' - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image'
printf '%s\n' ' - `$IMAGE_PULL_SECRET_NAME` - the name of the pull secret used to pull this image (default: `sconeapps`). For simplicity, we assume we can use the same pull secret for both the native and confidential workloads.'
printf '%s\n' ' - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1) '
printf '%s\n' ' - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)'
printf '%s\n' ' - `$CAS_NAME` - The CAS name to use (e.g., `cas`) '
printf '%s\n' ' - `$CVM_MODE` - if you want CVM mode, set it to `--cvm`. For SGX, leave it empty.'
printf '%s\n' ' - `$SCONE_ENCLAVE` - in CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata Pods (leave it empty).'
printf '%s\n' ''
printf '%s\n' 'To render the manifests, we need to define the signer key used to sign policies. We determine the local SIGNER first but you can overwrite manually.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export SIGNER="$(scone self show-session-signing-key)"'
printf "${RESET}"

export SIGNER="$(scone self show-session-signing-key)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Program `tplenv` asks the user whether to keep the current (default) configuration stored in `Values.yaml`.'
printf '%s\n' 'Note that `Values.yaml` has priority over environment variables.'
printf '%s\n' 'If the user changes values, they are written to `Values.yaml`.'
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask for all environment variables described in `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file  --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file  --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 🧱 4. Build the Native Rust Image'
printf '%s\n' ''
printf '%s\n' 'This step builds a native version of the image to validate behavior before enforcing protection with SCONE.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'pushd folder-reader'
printf '%s\n' 'docker build -t ${DEMO_IMAGE} .'
printf '%s\n' 'docker push ${DEMO_IMAGE}'
printf '%s\n' ''
printf '%s\n' 'popd'
printf "${RESET}"

pushd folder-reader
docker build -t ${DEMO_IMAGE} .
docker push ${DEMO_IMAGE}

popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧩 Step 5: Render the Manifest'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'We then instantiate the manifest templates:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml  --indent'
printf '%s\n' 'tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml  --indent'
printf "${RESET}"

tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml  --indent
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml  --indent

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> Make sure the image name was correctly substituted in the manifest.native.yaml file before applying it with kubectl.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🔑 6. Add Docker Registry Secret to Kubernetes'
printf '%s\n' ''
printf '%s\n' 'We assume you need a pull secret to pull both the native and confidential container images. First, we check whether the pull secret is already set. If it is not, we ask the user for the information needed to create it:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.'
printf '%s\n' '- `$REGISTRY_USER` - the login name of the user that pulls the container image.'
printf '%s\n' '- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.'
printf '%s\n' ''
printf '%s\n' 'Note that `tplenv` stores this information in `Values.yaml`.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )'
printf '%s\n' '  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # ask user for the credentials for accessing the registry
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧪 7. Deploy the Native App [OPTIONAL]'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifests/manifest.yaml'
printf '%s\n' ''
printf '%s\n' 'retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -c reader-1'
printf '%s\n' 'retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -c reader-2'
printf '%s\n' ''
printf '%s\n' '# Clean up native app'
printf '%s\n' 'kubectl delete -f manifests/manifest.yaml'
printf "${RESET}"

kubectl apply -f manifests/manifest.yaml

retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -c reader-1
retry-spinner --retries 5 --wait 2 -- kubectl logs job/my-rust-app -c reader-2

# Clean up native app
kubectl delete -f manifests/manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '✅ Your containers should log content from their mounted ConfigMap files.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧩 8. Prepare and Apply the SCONE Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build from -y manifests/scone.yaml'
printf "${RESET}"

scone-td-build from -y manifests/scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This step:'
printf '%s\n' ''
printf '%s\n' '- Generates a SCONE session'
printf '%s\n' '- Attaches it to your manifest'
printf '%s\n' '- Produces a new `manifests/manifest.prod.sanitized.yaml` with the necessary information to use the created session'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🚀 9. Deploy the SCONE-Protected App'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifests/manifest.prod.sanitized.yaml'
printf "${RESET}"

kubectl apply -f manifests/manifest.prod.sanitized.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 📜 10. View Logs'
printf '%s\n' ''
printf '%s\n' 'Check that SCONE-protected containers can access the expected ConfigMap data:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow'
printf '%s\n' 'retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow'
printf "${RESET}"

retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow
retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧹 11. Clean Up'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f manifests/manifest.prod.sanitized.yaml'
printf "${RESET}"

kubectl delete -f manifests/manifest.prod.sanitized.yaml

