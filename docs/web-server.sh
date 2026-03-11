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
printf '%s\n' 'This Rust application is a minimal web service built with [Axum](https://github.com/tokio-rs/axum). It is intentionally small and easy to follow.'
printf '%s\n' ''
printf '%s\n' '[![Web-Server Example](../docs/web-server.gif)](../docs/web-server.mp4)'
printf '%s\n' ''
printf '%s\n' '## Endpoints'
printf '%s\n' ''
printf '%s\n' '- **Generate password (`/gen`)**'
printf '%s\n' '  - Generates a random alphanumeric password.'
printf '%s\n' '  - Example response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "password": "aBcD1234EeFgH5678"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print path (`/path`)**'
printf '%s\n' '  - Reads files from `/config` and returns file names and contents.'
printf '%s\n' '  - Example response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "name": "file1.txt",'
printf '%s\n' '    "content": "This is the content of file1.txt.\n..."'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print environment variable (`/env/:env`)**'
printf '%s\n' '  - Returns the value of the requested environment variable.'
printf '%s\n' '  - Example response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "value": "your_env_value_here"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Assume you start in `scone-td-build-demos`, then switch to this demo:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
pushd web-server
EOF
)"
pe "$(cat <<'EOF'
rm storage.json || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native `web-server` image'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Attest CAS before sending encrypted policies:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, review the output for detected issues and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' 'Render the manifest template:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Build and Register the Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the native image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
docker build -t ${IMAGE_NAME} .
EOF
)"
pe "$(cat <<'EOF'
docker push ${IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate a signing key for confidential binaries if needed:'
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
printf '%s\n' 'Register the image with `scone-td-build`:'
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
printf '%s\n' '## 5. Test the Native Manifest (Optional)'
printf '%s\n' ''
printf '%s\n' 'Clean up previous runs first:'
printf '%s\n' ''
printf "%b" "$RESET"

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
printf '%s\n' 'Deploy and test:'
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
kill $(cat /tmp/pf-8000.pid) || true
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-8000.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Convert the Manifest'
printf '%s\n' ''
printf '%s\n' 'If you want to inspect registration details, see [register-image](../../../register-image.md).'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
scone-td-build apply \
  -f manifest.yaml \
  -c ${CAS_NAME}.${CAS_NAMESPACE} \
  -s ./storage.json \
  --spol \
  --manifest-env SCONE_SYSLIBS=1 \
  --manifest-env SCONE_VERSION=1 \
  --session-env SCONE_VERSION=1 \
  --version ${SCONE_VERSION} -p
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f manifest.cleaned.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '## 8. Run the Demo'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
EOF
)"
pe "$(cat <<'EOF'
# A ready pod does not always mean the port is immediately available.
EOF
)"
pe "$(cat <<'EOF'
sleep 20
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Send test requests:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
EOF
)"
pe "$(cat <<'EOF'
retry-spinner -- curl http://localhost:8000/gen
EOF
)"
pe "$(cat <<'EOF'
./test.sh
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 9. Uninstall the Demo'
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
printf '%s\n' 'This demo provides a simple but functional Rust web service that you can extend as needed.'
printf "%b" "$RESET"

