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
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-}"

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
printf '%s\n' '# 🛡️ SCONE: Hello World'
printf '%s\n' ''
printf '%s\n' '## Steps to Run the Hello World Program'
printf '%s\n' ''
printf '%s\n' '![Hello-World Example](../docs/hello-world.gif)'
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
printf '%s\n' '#### 3. Setting up the Environment Variables'
printf '%s\n' ''
printf '%s\n' 'We build a simple cloud-native `hello world` image. For this, we use Rust. Rust is available as the container image `rust:latest` on Docker Hub. We define a `Dockerfile` that uses this image to create a `hello world` image:'
printf '%s\n' ''
printf '%s\n' '- it creates a new Rust crate using `cargo`'
printf '%s\n' '- the new crate is actually defining a `hello world` program'
printf '%s\n' '- we build this project and push it to a repository where we have push access:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.
EOF
)"
pe "$(cat <<'EOF'
pushd hello-world
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The default values of several environment variables are defined in file `Values.yaml`.'
printf '%s\n' '`tplenv` asks whether all defaults are okay. It then sets the environment variables:'
printf '%s\n' ''
printf '%s\n' ' - `$IMAGE_NAME` - name of the native container image to deploy the `hello-world` application,'
printf '%s\n' ' - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image'
printf '%s\n' ' - `$IMAGE_PULL_SECRET_NAME` - the name of the pull secret used to pull this image (default: `sconeapps`). For simplicity, we assume we can use the same pull secret for both the native and confidential workloads.'
printf '%s\n' ' - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1 for now) '
printf '%s\n' ' - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)'
printf '%s\n' ' - `$CAS_NAME` - The CAS name to use (e.g., `cas`) '
printf '%s\n' ' - `$CVM_MODE` - if you want CVM mode, set it to `--cvm`. For SGX, leave it empty.'
printf '%s\n' ' - `$SCONE_ENCLAVE` - in CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata Pods (leave it empty).'
printf '%s\n' ''
printf '%s\n' 'Program `tplenv` asks the user whether to keep the current (default) configuration stored in `Values.yaml`.'
printf '%s\n' 'Note that `Values.yaml` has priority over environment variables.'
printf '%s\n' 'If the user changes values, they are written to `Values.yaml`.'
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask for all environment variables described in `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We encrypt the policies that we send to CAS to ensure the integrity and confidentiality of the policies. To do so, we need to attest the CAS. We do this using a plugin of `kubectl` that attests the CAS via the Kubernetes API:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# attest the CAS - to ensure that we know the correct session encryption key
EOF
)"
pe "$(cat <<'EOF'
kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME} -C -G -S
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'In case the attestation and verification of the CAS would fail, please read the output of `kubectl scone cas attest` to determine which vulnerabilities were detected. It also suggests which options to pass to `kubectl scone cas attest` to tolerate these vulnerabilities, i.e., to make the attestation and verification to succeed.'
printf '%s\n' ''
printf '%s\n' 'Next, we need to customize the job manifest to set the right image name (`$IMAGE_NAME`) and the right pull secret (`$IMAGE_PULL_SECRET_NAME`):'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# customize the job manifest
EOF
)"
pe "$(cat <<'EOF'
tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '#### 4. Build and Register Image'
printf '%s\n' ''
printf '%s\n' 'Now we create the native `hello-world` application using Rust. Note that we could create the `hello-world` program inside the `Dockerfile` (see below) used to build the native container image. To keep this example easy to customize, we create the Rust files directly.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# create the hello-world application
EOF
)"
pe "$(cat <<'EOF'
cargo new hello-world || echo "Hello World already exists - using existing one"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We compile the application within a Rust image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# build the hello-world app in a Container
EOF
)"
pe "$(cat <<'EOF'
docker build -t $IMAGE_NAME .
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If you have permission to push to `$IMAGE_NAME`, push the container image. If you use the default image name, you can use the pre-built container image (that is, there is no need to push the image).'
printf '%s\n' ''
printf '%s\n' 'docker push $IMAGE_NAME'
printf '%s\n' ''
printf '%s\n' '## 5. Sconifying the Application'
printf '%s\n' ''
printf '%s\n' 'We need to identify the programs that must run confidentially. To do so, we identify all programs in the image that might run confidentially. We can explicitly specify all binaries that must be confidential by using the following options for `scone-td-build register`:'
printf '%s\n' ''
printf '%s\n' '-  `--enforce <ENFORCE>` '
printf '%s\n' '          Set enforced binaries to ensure that these binaries in the protected image are executed confidentially in the destination image. To define multiple binaries, use this flag multiple times.'
printf '%s\n' ''
printf '%s\n' '- `--enforce-list <ENFORCE_LIST>`'
printf '%s\n' '          Specify a file that contains a list of binary filenames in the protected image. All binaries in the list will run confidentially in the destination image.'
printf '%s\n' ''
printf '%s\n' 'Alternatively, we could assume that all binaries might run confidentially. That might result in many programs being transformed. To reduce the number of binaries that need to be transformed and the effort of specifying all confidential binaries, we use the following approach:'
printf '%s\n' ''
printf '%s\n' '- `scone-td-build register` first determines all programs of a base image: we call this image the  `unprotected-image`'
printf '%s\n' '- `scone-td-build register` then determines all programs of the container image used by the cloud-native application:  we call this image the `protected-image`'
printf '%s\n' ''
printf '%s\n' 'We register a new image for later manifest translation: the manifest is protected so that a Kubernetes cluster admin cannot modify or read an application'\''s `ConfigMaps` and `Secrets`.'
printf '%s\n' ''
printf '%s\n' 'Our translation generates a new image by appending the suffix `-scone` to the original image name, unless we define a new image name with `--destination-image`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Registering images allows us to copy images into our own repository. This decouples our application from changes in the upstream repository that contains the original container image (in this case, `$IMAGE_NAME`).'
printf '%s\n' ''
printf '%s\n' '#### 6. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'We assume you need a pull secret to pull both the native and confidential container images. First, we check whether the pull secret is already set. If it is not, we ask the user for the information needed to create it:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.'
printf '%s\n' '- `$REGISTRY_USER` - the login name of the user that pulls the container image.'
printf '%s\n' '- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.'
printf '%s\n' ''
printf '%s\n' 'Note that `tplenv` stores this information in `Values.yaml`.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  # ask user for the credentials for accessing the registry
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '#### 7. Convert the manifests'
printf '%s\n' ''
printf '%s\n' 'Next, we use the native Kubernetes manifests and transform them into *sanitized* manifests.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  ${CVM_MODE} ${SCONE_ENCLAVE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '#### 8. Apply the new manifest'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Ensure that previous run is not running anymore
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job hello-world || echo "ok - no previous job that we need to delete"
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifest.job.cleaned.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We need to wait briefly before the job logs become available. Therefore, we execute the command within the `retry-spinner` retry wrapper:'
printf '%s\n' ''
printf '%s\n' 'Let'\''s see the output of the job'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
retry-spinner -- kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '#### 9. Uninstall `hello-world`'
printf '%s\n' ''
printf '%s\n' 'Delete the job that we just created:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl delete job hello-world 
EOF
)"
pe "$(cat <<'EOF'
popd
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Automation'
printf '%s\n' ''
printf '%s\n' 'You can execute the steps in this document automatically by running `./scripts/hello-world.sh`. Note that this will not ask for user input; it will use the configuration in `hello-world/Values.yaml`.'
printf '%s\n' ''
printf '%s\n' 'If you update the commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.'
printf "%b" "$RESET"

