#!/usr/bin/env bash

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

printf "%b" "$LILAC"
cat <<'EOF'
# 🛡️ SCONE ConfigMap Example: Secure Your Configurations in Kubernetes

This example walks you through how to securely manage and access configuration data in Kubernetes using a `ConfigMap` and a SCONE-enabled Rust application. You’ll start with a plain (unencrypted) deployment, then transition to a fully protected SCONE deployment.

![ConfigMap Example](../docs/configmap.webm)

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


EOF
printf "%b" "$RESET"

pe 'pushd configmap'
pe '# ensure that the following is not set'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

printf "%b" "$LILAC"
cat <<'EOF'

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

export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"

`tplenv` will now ask the user for all environment variables that are described in file `environment-variables.md`:

EOF
printf "%b" "$RESET"

pe 'eval $(tplenv --file environment-variables.md --create-values-file  --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

printf "%b" "$LILAC"
cat <<'EOF'

## 🧱 4. Build the Native Rust Image

This step builds a native version of the image to validate behavior before enforcing protection with SCONE.

EOF
printf "%b" "$RESET"

pe 'pushd folder-reader'
pe 'docker build -t ${DEMO_IMAGE} .'
pe 'docker push ${DEMO_IMAGE}'
pe ''
pe 'popd'

printf "%b" "$LILAC"
cat <<'EOF'

______________________________________________________________________

## 🧩 Step 5: Render the Manifest

To render the manifests, we first need to define the signer key used to sign policies:

EOF
printf "%b" "$RESET"

pe 'export SIGNER="$(scone self show-session-signing-key)"'

printf "%b" "$LILAC"
cat <<'EOF'

We then instantiate the manifest templates:

EOF
printf "%b" "$RESET"

pe 'tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml  --indent'
pe 'tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml  --indent'

printf "%b" "$LILAC"
cat <<'EOF'

> Make sure the image name was correctly substituted in the manifest.native.yaml file before applying it with kubectl.

______________________________________________________________________

## 🔑 6. Add Docker Registry Secret to Kubernetes

We assume that you need a pull secret to pull the native and the confidential container image. We first check if the pull secret is already set. If it is not set, we ask the user to input the necessary information to create the pull secret:

- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.
- `$REGISTRY_USER` - the login name of the user that pulls the container image.
- `$REGISTRY_TOKEN` - the token to pull the secret. See <https://sconedocs.github.io/registry/> for how to create this token.

Note that `tplenv` stores this information in file `Values.yaml`. 

EOF
printf "%b" "$RESET"

pe 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
pe '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
pe 'else'
pe '  echo "Secret ${IMAGE_PULL_SECRET_NAME} not exist - creating now."'
pe '  # ask user for the credentials for accessing the registry'
pe '  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )'
pe '  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
pe 'fi'

printf "%b" "$LILAC"
cat <<'EOF'

______________________________________________________________________

## 🧪 7. Deploy the Native App [OPTIONAL]

EOF
printf "%b" "$RESET"

pe 'kubectl apply -f manifests/manifest.yaml'
pe ''
pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-1'
pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-2'
pe ''
pe '# Clean up native app'
pe 'kubectl delete -f manifests/manifest.yaml'

printf "%b" "$LILAC"
cat <<'EOF'

✅ Your containers should log content from their mounted ConfigMap files.

______________________________________________________________________

## 🧩 8. Prepare and Apply the SCONE Manifest

EOF
printf "%b" "$RESET"

pe 'scone-td-build from -y manifests/scone.yaml'

printf "%b" "$LILAC"
cat <<'EOF'

This step:

- Generates a SCONE session
- Attaches it to your manifest
- Produces a new `manifests/manifest.prod.sanitized.yaml` with the necessary information to use the created session

______________________________________________________________________

## 🚀 9. Deploy the SCONE-Protected App

EOF
printf "%b" "$RESET"

pe 'kubectl apply -f manifests/manifest.prod.sanitized.yaml'

printf "%b" "$LILAC"
cat <<'EOF'

______________________________________________________________________

## 📜 10. View Logs

Check that SCONE-protected containers can access the expected ConfigMap data:

EOF
printf "%b" "$RESET"

pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow'
pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow'

printf "%b" "$LILAC"
cat <<'EOF'

______________________________________________________________________

## 🧹 11. Clean Up

EOF
printf "%b" "$RESET"

pe 'kubectl delete -f manifests/manifest.prod.sanitized.yaml'

