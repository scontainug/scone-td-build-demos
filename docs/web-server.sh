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
# Web Server Demo

## Introduction

This Rust application serves as a minimalistic web service built using the [Axum](https://github.com/tokio-rs/axum) framework.
While it's more functional than a traditional "Web Server" program, it remains straightforward and easy to understand. Let's break it down:

## Endpoints

- **Generate Password Endpoint (`/gen`)**:

  - Generates a random password consisting of alphanumeric characters.
  - Example Response:

  ```json
  {
    "password": "aBcD1234EeFgH5678"
  }
  ```

- **Print Path Endpoint (`/path`)**:

  - Reads files from the `/config` directory and returns their names and contents.
  - Example Response:

  ```json
  {
    "name": "file1.txt",
    "content": "This is the content of file1.txt.\n..."
  }
  ```

- **Print Environment Variable Endpoint (`/env/:env`)**:

  - Retrieves the value of the specified environment variable.
  - Example Response:

  ```json
  {
    "value": "your_env_value_here"
  }
  ```

## How to Run the Demo

### 1. Prerequisites

- A token for accessing `scone.cloud` images on registry.scontain.com
- A Kubernetes cluster
- The Kubernetes command line tool (`kubectl`)
- Rust `cargo` is installed (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

#### 2. Set up the environment

Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).

#### 3. Setting up the Environment Variables

We build a simple cloud-native `web-server` image. For that we use Rust. Rust is available as a container image `rust:latest` on Dockerhub. We define a `Dockerfile` that uses this Rust image to create a `hello world` image:

- it creates a new Rust crate using `cargo`
- the new crate is actually defining a `hello world` program
- we build this project and push it to a repository to which we have push rights:

EOF
printf "%b" "$RESET"

pe '# Ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`'
pe 'pushd web-server'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

printf "%b" "$LILAC"
cat <<'EOF'

The default values of several environment variables are defined in file `Values.yaml`.
`tplenv` asks you if all defaults are ok. It then sets the environment variables:

 - `$IMAGE_NAME` - name of the native container image to deploy the `hello-world` application,
 - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image
 - `$IMAGE_PULL_SECRET_NAME` the name of the pull secret to pull this image (default is `sconeapps`).  For simplicity, we assume that we can use the same pull secret to run the native and the confidential workload. 
 - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1 for now) 
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

pe 'eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

printf "%b" "$LILAC"
cat <<'EOF'

We encrypt the policies that we send to CAS to ensure the integrity and confidentiality of the policies. To do so, we need to attest the CAS. We do this using a plugin of `kubectl` that attests the CAS via the Kubernetes API:

EOF
printf "%b" "$RESET"

pe '# attest the CAS - to ensure that we know the correct session encryption key'
pe 'kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}'

printf "%b" "$LILAC"
cat <<'EOF'

In case the attestation and verification of the CAS would fail, please read the output of `kubectl scone cas attest` to determine which vulnerabilities were detected. It also suggests which options to pass to `kubectl scone cas attest` to tolerate these vulnerabilities, i.e., to make the attestation and verification to succeed.

Next, we need to customize the job manifest to set the right image name (`$IMAGE_NAME`) and the right pull secret (`$IMAGE_PULL_SECRET_NAME`):

EOF
printf "%b" "$RESET"

pe '# customize the job manifest'
pe 'tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml'

printf "%b" "$LILAC"
cat <<'EOF'

4. **Register image:**

Now, we create the native `web-server` application using Rust.

EOF
printf "%b" "$RESET"

pe '# Build the Scone image for the demo client'
pe 'docker build -t ${IMAGE_NAME} .'
pe ''
pe '# Push it to the registry'
pe 'docker push ${IMAGE_NAME}'

printf "%b" "$LILAC"
cat <<'EOF'

When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. `scone-td-build` assumes, by default, that this key is stored in file `identity.pem`. We can generate this file as follows:

- we first check if the file exists, and
- if it does not yet exist, we create with `openssl`

EOF
printf "%b" "$RESET"

pe 'if [ ! -f identity.pem ]; then'
pe '  echo "Generating identity.pem ..."'
pe '  openssl genrsa -3 -out identity.pem 3072'
pe 'else'
pe '  echo "identity.pem already exists."'
pe 'fi'

printf "%b" "$LILAC"
cat <<'EOF'

EOF
printf "%b" "$RESET"

pe 'scone-td-build register \'
pe '    --protected-image ${IMAGE_NAME} \'
pe '    --unprotected-image ${IMAGE_NAME} \'
pe '    --destination-image ${DESTINATION_IMAGE_NAME} \'
pe '    --push \'
pe '    -s ./storage.json \'
pe '    --enforce /app/web-server \'
pe '    --version ${SCONE_VERSION}'

printf "%b" "$LILAC"
cat <<'EOF'

1. **Test the manifest [optional]**:

First, we clean up - just in case a previous version is running:

EOF
printf "%b" "$RESET"

pe '# Make sure web-server does not yet run'
pe 'kubectl delete deployment web-server || echo "ok - no web-server deployment yet"'
pe 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
pe 'kill $(cat /tmp/pf-8000.pid) || true'

printf "%b" "$LILAC"
cat <<'EOF'

Second, we start the deployment

EOF
printf "%b" "$RESET"

pe 'kubectl apply -f manifest.yaml'
pe 'kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
pe ''
pe '# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps'
pe '# Use this command in another terminal or add `&` at the end of the command to run in the background'
pe 'kubectl port-forward deployment/web-server 8000:8000 &'
pe 'echo $! > /tmp/pf-8000.pid'
pe ''
pe 'retry-spinner -- curl http://localhost:8000/env/MY_POD_IP'
pe './test.sh'
pe ''
pe 'kubectl delete -f manifest.yaml'
pe 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
pe ''
pe '# Close the port forward after the execution'
pe 'kill $(cat /tmp/pf-8000.pid) || true'
pe 'rm /tmp/pf-8000.pid'

printf "%b" "$LILAC"
cat <<'EOF'

6. **Convert the manifest**:

If you want to see how the scone image was registered in scone-td-build, take a look in [register-image](../../../register-image.md) markdown.

EOF
printf "%b" "$RESET"

pe 'scone-td-build apply \'
pe '    -f manifest.yaml \'
pe '    -c ${CAS_NAME}.${CAS_NAMESPACE} \'
pe '    -s ./storage.json \'
pe '    --manifest-env SCONE_SYSLIBS=1 \'
pe '    --manifest-env SCONE_VERSION=1 \'
pe '    --session-env SCONE_VERSION=1 \'
pe '    --version ${SCONE_VERSION} -p'

printf "%b" "$LILAC"
cat <<'EOF'

7. **Deploy the new manifest**:

EOF
printf "%b" "$RESET"

pe 'kubectl apply -f manifest.cleaned.yaml'

printf "%b" "$LILAC"
cat <<'EOF'

   > For the next step, it is expected that you have a Kubernetes cluster with SGX resource and the presence of a LAS

8. **Run the demo**:

We wait for the pod to become ready before we try a port-forward to access the `web-server`:

EOF
printf "%b" "$RESET"

pe 'kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
pe '# being ready does not mean that port is available'
pe 'sleep 20'
pe ''
pe 'kubectl port-forward deployment/web-server 8000:8000 &'
pe '# we keep to PID to be able to delete the port-forward'
pe 'echo $! > /tmp/pf-8000.pid'

printf "%b" "$LILAC"
cat <<'EOF'

We now send the first request. We do this with some retry just to ensure that the service is indeed ready to serve requests. 
 
We execute the [`test.sh`](./test.sh) to run all of these tests more easily:

EOF
printf "%b" "$RESET"

pe '# Test path - result in error'
pe 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path'
pe ''
pe '# Test gen'
pe 'retry-spinner -- curl http://localhost:8000/gen'
pe ''
pe '# Test env'
pe './test.sh'

printf "%b" "$LILAC"
cat <<'EOF'

9. **Uninstall demo**:

EOF
printf "%b" "$RESET"

pe 'kubectl delete -f manifest.cleaned.yaml'
pe 'kill $(cat /tmp/pf-8000.pid) || true'
pe 'rm /tmp/pf-8000.pid'
pe 'popd'

printf "%b" "$LILAC"
cat <<'EOF'

We introduced a simple, yet functional "Web Server" web service in Rust! Feel free to explore and modify this demo to suit your needs.
If you have any questions or need further assistance, feel free to ask! 😊🚀
EOF
printf "%b" "$RESET"

