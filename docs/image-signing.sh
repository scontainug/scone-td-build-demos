#!/usr/bin/env bash
# Generated file. Do not edit manually.

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

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs a demo-style shell script generated from image-signing/README.md.

Options:
  --help             Show this help message and exit.
  --non-interactive  Do not force confirmation for existing tplenv values.
USAGE
}

NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      echo "Error: This script does not accept positional arguments." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Error: This script does not accept positional arguments." >&2
  show_help >&2
  exit 1
fi

unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "%b" "$LILAC"
printf '%s\n' '# SCONE: Image Signing'
printf '%s\n' ''
printf '%s\n' 'This example shows how to sign and encrypt a confidential container image using a Sigstore private'
printf '%s\n' 'key, then verify the signature before deploying it to Kubernetes.'
printf '%s\n' ''
printf '%s\n' 'Image signing provides supply chain integrity: only images signed with a trusted private key pass'
printf '%s\n' 'verification. Combined with SCONE encryption, the image layers are also protected at rest in the'
printf '%s\n' 'registry.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- `skopeo` for image inspection and signature verification'
printf '%s\n' '- `openssl` for signing key generation'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install the required tools:'
printf '%s\n' ''
printf '%s\n' '- VM/laptop setup: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md)'
printf '%s\n' '- Kubernetes-based setup: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'We assume you start in `scone-td-build-demos`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Enter `image-signing` and remember the previous directory.
EOF
)"
pe "$(cat <<'EOF'
pushd image-signing
EOF
)"
pe "$(cat <<'EOF'
# Remove `storage.json` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm -f storage.json || true
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This example uses the following variables.'
printf '%s\n' ''
printf '%s\n' 'For the native deployment:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native container image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name for this image (default: `sconeapps`)'
printf '%s\n' ''
printf '%s\n' 'For the signing and confidential deployment:'
printf '%s\n' ''
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the SCONE-protected image'
printf '%s\n' '- `$REPO_CREDENTIALS` - Path to Docker credentials file used by the signing push (default: `~/.docker/config.json`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS Kubernetes namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS Kubernetes name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' '- `$NAMESPACE` - Kubernetes namespace where the demo runs (default: `ci-scone-td-build`)'
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Kubernetes namespace if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate the job manifest with the selected image and pull-secret values:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 3. Deploy Key Management Infrastructure'
printf '%s\n' ''
printf '%s\n' 'The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in'
printf '%s\n' 'the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Deploy the Key Broker Service.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f k8s/kbs.yaml
EOF
)"
pe "$(cat <<'EOF'
# Deploy the key provider.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f k8s/key-provider.yaml
EOF
)"
pe "$(cat <<'EOF'
# Wait for KBS to be ready.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=available deployment/kbs -n trustee --timeout=120s
EOF
)"
pe "$(cat <<'EOF'
# Wait for the key provider to be ready.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=available deployment/keyprovider -n trustee --timeout=120s
EOF
)"
pe "$(cat <<'EOF'
# Kill any existing listener on port 50000 before starting the port-forward.
EOF
)"
pe "$(cat <<'EOF'
lsof -i :50000 -t 2>/dev/null | xargs -r kill 2>/dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Forward the key provider port to localhost so skopeo can reach it.
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward -n trustee svc/keyprovider 50000:50000 &
EOF
)"
pe "$(cat <<'EOF'
export PORT_FORWARD_PID=$!
EOF
)"
pe "$(cat <<'EOF'
# Give the port-forward a moment to establish the connection.
EOF
)"
pe "$(cat <<'EOF'
sleep 3
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 4. Generate Signing Keys'
printf '%s\n' ''
printf '%s\n' 'Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed'
printf '%s\n' 'to verify signatures without exposing the private key.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the Ed25519 signing key pair in the format expected by skopeo.
EOF
)"
pe "$(cat <<'EOF'
skopeo generate-sigstore-key --output-prefix ./config/image-signing-key --passphrase-file ./config/empty-passphrase.txt
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Configure the registry to store signatures as sigstore OCI attachments:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Configure sigstore attachments for the registry (user-level, no sudo required).
EOF
)"
pe "$(cat <<'EOF'
mkdir -p ~/.config/containers/registries.d
EOF
)"
pe "$(cat <<'EOF'
cat <<EOF > ~/.config/containers/registries.d/default.yaml
EOF
)"
pe "$(cat <<'EOF'
docker:
EOF
)"
pe "$(cat <<'EOF'
    ${REGISTRY}:
EOF
)"
pe "$(cat <<'EOF'
        use-sigstore-attachments: true
EOF
)"
pe "$(cat <<'EOF'
EOF
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 5. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Create the Rust project (or reuse an existing one):'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Create the Rust project in `hello-world` if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
cargo new hello-world || echo "hello-world already exists - using existing one"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t $IMAGE_NAME .
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push $IMAGE_NAME
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 6. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
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
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
EOF
)"
pe "$(cat <<'EOF'
  # Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
EOF
)"
pe "$(cat <<'EOF'
  # Create the Docker registry pull secret.
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 7. Run the Native Application'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
EOF
)"
pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifest.job.yaml -n ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete job image-signing -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 8. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Before sending encrypted policies to CAS, attest CAS via the Kubernetes API:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Attest the CAS instance before sending encrypted policies.
EOF
)"
pe "$(cat <<'EOF'
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 9. Register and Sign the Confidential Image'
printf '%s\n' ''
printf '%s\n' 'The `--signing-key` flag activates the encrypted-image flow: `scone-td-build` sconifies the image,'
printf '%s\n' 'then uses `skopeo` to encrypt the layers with the attestation-agent key provider and embed a'
printf '%s\n' 'Sigstore signature. When `--destination-image` is set the result is pushed directly to'
printf '%s\n' '`${DESTINATION_IMAGE_NAME}` (no `-encrypted` suffix is added).'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Register, sign, and encrypt the confidential image.
EOF
)"
pe "$(cat <<'EOF'
OCICRYPT_KEYPROVIDER_CONFIG=./config/ocicrypt.conf \
  scone-td-build register \
    --protected-image $IMAGE_NAME \
    --unprotected-image rust:latest \
    --manifest-env SCONE_PRODUCTION=0 \
    -s ./storage.json \
    --destination-image ${DESTINATION_IMAGE_NAME} \
    --signing-key ./config/image-signing-key.private \
    --signing-passphrase-file ./config/empty-passphrase.txt \
    --repo-credentials ${REPO_CREDENTIALS} \
    --version ${SCONE_RUNTIME_VERSION} \
    ${CVM_MODE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 10. Verify Image Signature'
printf '%s\n' ''
printf '%s\n' 'Inspect the signed and encrypted image to confirm the Sigstore signature is attached:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Inspect the signed and encrypted image.
EOF
)"
pe "$(cat <<'EOF'
skopeo inspect docker://${DESTINATION_IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## 11. Transform and Deploy the Signed Confidential Application'
printf '%s\n' ''
printf '%s\n' '> **Blocked:** This step requires `ctd-decoder` to be installed on every cluster node and'
printf '%s\n' '> containerd to be configured with the `ocicrypt` stream processor so it can decrypt the encrypted'
printf '%s\n' '> image layers at pull time. Plain k3d clusters do not include this. See'
printf '%s\n' '> [containers/ocicrypt](https://github.com/containers/ocicrypt) for setup instructions.'
printf '%s\n' '>'
printf '%s\n' '> Once the cluster has `ctd-decoder`, run:'
printf '%s\n' '>'
printf '%s\n' '> ```text'
printf '%s\n' '> scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json \'
printf '%s\n' '>   --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --manifest-env SCONE_HEAP=1G \'
printf '%s\n' '>   --spol --manifest-env SCONE_VERSION=1 --output-manifest-file manifest.job.sanitized.yaml \'
printf '%s\n' '>   --version ${SCONE_RUNTIME_VERSION} ${CVM_MODE} ${SCONE_ENCLAVE}'
printf '%s\n' '>'
printf '%s\n' '> kubectl apply -f manifest.job.sanitized.yaml -n ${NAMESPACE}'
printf '%s\n' '> kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '> kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf '%s\n' '> ```'
printf '%s\n' ''
printf '%s\n' '## 12. Uninstall `image-signing`'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the key provider port-forward.
EOF
)"
pe "$(cat <<'EOF'
kill ${PORT_FORWARD_PID} 2>/dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Delete the key provider.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f k8s/key-provider.yaml
EOF
)"
pe "$(cat <<'EOF'
# Delete the Key Broker Service.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f k8s/kbs.yaml
EOF
)"
pe "$(cat <<'EOF'
# Return to the previous working directory.
EOF
)"
pe "$(cat <<'EOF'
popd
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '## Automation'
printf '%s\n' ''
printf '%s\n' 'You can run this workflow with:'
printf '%s\n' ''
printf '%s\n' './scripts/image-signing.sh'
printf '%s\n' ''
printf '%s\n' 'It asks for user input unless you set:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"'
printf '%s\n' ''
printf '%s\n' 'This uses values from `image-signing/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.'
printf '%s\n' ''
printf '%s\n' 'If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/image-signing.sh`.'
printf "%b" "$RESET"

