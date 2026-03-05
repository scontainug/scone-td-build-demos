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
printf '%s\n' '# Web Server Demo'
printf '%s\n' ''
printf '%s\n' '## Introduction'
printf '%s\n' ''
printf '%s\n' 'This Rust application is a minimal web service built with the [Axum](https://github.com/tokio-rs/axum) framework.'
printf '%s\n' 'While it is more functional than a traditional "web server" example, it remains straightforward and easy to understand.'
printf '%s\n' ''
printf '%s\n' '![Web-Server Example](../docs/web-server.gif)'
printf '%s\n' ''
printf '%s\n' '## Endpoints'
printf '%s\n' ''
printf '%s\n' '- **Generate Password Endpoint (`/gen`)**:'
printf '%s\n' ''
printf '%s\n' '  - Generates a random password consisting of alphanumeric characters.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "password": "aBcD1234EeFgH5678"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print Path Endpoint (`/path`)**:'
printf '%s\n' ''
printf '%s\n' '  - Reads files from the `/config` directory and returns their names and contents.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "name": "file1.txt",'
printf '%s\n' '    "content": "This is the content of file1.txt.\n..."'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print Environment Variable Endpoint (`/env/:env`)**:'
printf '%s\n' ''
printf '%s\n' '  - Retrieves the value of the specified environment variable.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "value": "your_env_value_here"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '## How to Run the Demo'
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
printf '%s\n' 'We build a simple cloud-native `web-server` image. For this, we use Rust. Rust is available as the container image `rust:latest` on Docker Hub. We define a `Dockerfile` that uses this image to create a `web-server` image:'
printf '%s\n' ''
printf '%s\n' '- it creates a new Rust crate using `cargo`'
printf '%s\n' '- the new crate defines the `web-server` program'
printf '%s\n' '- we build this project and push it to a repository where we have push access:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.
EOF
)"
pe "$(cat <<'EOF'
pushd web-server
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The default values of several environment variables are defined in file `Values.yaml`.'
printf '%s\n' '`tplenv` asks whether all defaults are okay. It then sets the environment variables:'
printf '%s\n' ''
printf '%s\n' ' - `$IMAGE_NAME` - name of the native container image to deploy the `web-server` application,'
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
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
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
tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '4. **Register image**'
printf '%s\n' ''
printf '%s\n' 'Now, we create the native `web-server` application using Rust.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the Scone image for the demo client
EOF
)"
pe "$(cat <<'EOF'
docker build -t ${IMAGE_NAME} .
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Push it to the registry
EOF
)"
pe "$(cat <<'EOF'
docker push ${IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. `scone-td-build` assumes, by default, that this key is stored in file `identity.pem`. We can generate this file as follows:'
printf '%s\n' ''
printf '%s\n' '- we first check if the file exists, and'
printf '%s\n' '- if it does not exist, we create it with `openssl`'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
if [ ! -f identity.pem ]; then
EOF
)"
pe "$(cat <<'EOF'
  echo "Generating identity.pem ..."
EOF
)"
pe "$(cat <<'EOF'
  openssl genrsa -3 -out identity.pem 3072
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  echo "identity.pem already exists."
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
scone-td-build register \
    --protected-image ${IMAGE_NAME} \
    --unprotected-image ${IMAGE_NAME} \
    --destination-image ${DESTINATION_IMAGE_NAME} \
    --push \
    -s ./storage.json \
    --enforce /app/web-server \
    --version ${SCONE_VERSION}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '5. **Test the manifest [optional]**'
printf '%s\n' ''
printf '%s\n' 'First, we clean up, just in case a previous version is running:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Make sure web-server does not yet run
EOF
)"
pe "$(cat <<'EOF'
kubectl delete deployment web-server || echo "ok - no web-server deployment yet"
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=web-server --timeout=240s || echo "ok - no web-server deployment yet"
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-8000.pid) || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Second, we start the deployment.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f manifest.yaml
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps
EOF
)"
pe "$(cat <<'EOF'
# Use this command in another terminal, or run it in the background by appending `&`.
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
EOF
)"
pe "$(cat <<'EOF'
./test.sh
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f manifest.yaml
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=web-server --timeout=240s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Close the port forward after execution
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-8000.pid) || true
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-8000.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '6. **Convert the manifest**'
printf '%s\n' ''
printf '%s\n' 'If you want to see how the SCONE image was registered with `scone-td-build`, see [register-image](../../../register-image.md).'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
scone-td-build apply \
    -f manifest.yaml \
    -c ${CAS_NAME}.${CAS_NAMESPACE} \
    -s ./storage.json \
    --manifest-env SCONE_SYSLIBS=1 \
    --manifest-env SCONE_VERSION=1 \
    --session-env SCONE_VERSION=1 \
    --version ${SCONE_VERSION} -p
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '7. **Deploy the new manifest**'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f manifest.cleaned.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '> For the next step, it is expected that you have a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '8. **Run the demo**'
printf '%s\n' ''
printf '%s\n' 'We wait for the pod to become ready before we try a port-forward to access the `web-server`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s
EOF
)"
pe "$(cat <<'EOF'
# being ready does not mean that port is available
EOF
)"
pe "$(cat <<'EOF'
sleep 20
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# We keep the PID so we can stop the port-forward process later.
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid 
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'We now send the first request. We add retries to ensure that the service is ready to serve requests.'
printf '%s\n' ''
printf '%s\n' 'We execute the [`test.sh`](./test.sh) to run all of these tests more easily:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Test path - result in error
EOF
)"
pe "$(cat <<'EOF'
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Test gen
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- curl http://localhost:8000/gen
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Test env
EOF
)"
pe "$(cat <<'EOF'
./test.sh
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '9. **Uninstall the demo**'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl delete -f manifest.cleaned.yaml
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-8000.pid) || true
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-8000.pid
EOF
)"
pe "$(cat <<'EOF'
popd
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This demonstrates a simple, yet functional, Rust web service. Feel free to explore and modify this demo to suit your needs.'
printf "%b" "$RESET"

