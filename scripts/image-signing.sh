#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from image-signing/README.md.

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

if ! $NON_INTERACTIVE; then
  CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "${VIOLET}"
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Enter `image-signing` and remember the previous directory.'
printf '%s\n' 'pushd image-signing'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm -f storage.json || true'
printf "${RESET}"

# Enter `image-signing` and remember the previous directory.
pushd image-signing
# Remove `storage.json` if it exists.
rm -f storage.json || true

printf "${VIOLET}"
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
printf '%s\n' '- `$NAMESPACE` - Kubernetes namespace where the demo runs (default: `default`)'
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the Kubernetes namespace if it does not already exist.'
printf '%s\n' 'kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"'
printf "${RESET}"

# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching namespace ${NAMESPACE} failed -- ignoring this"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate the job manifest with the selected image and pull-secret values:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Deploy Key Management Infrastructure'
printf '%s\n' ''
printf '%s\n' 'The signing and encryption flow requires a Key Broker Service (KBS) and a key provider running in'
printf '%s\n' 'the cluster. The key provider exposes a gRPC endpoint that `skopeo` uses during image encryption.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Deploy the Key Broker Service.'
printf '%s\n' 'kubectl apply -f k8s/kbs.yaml'
printf '%s\n' '# Deploy the key provider.'
printf '%s\n' 'kubectl apply -f k8s/key-provider.yaml'
printf '%s\n' '# Wait for KBS to be ready.'
printf '%s\n' 'kubectl wait --for=condition=available deployment/kbs -n trustee --timeout=120s'
printf '%s\n' '# Wait for the key provider to be ready.'
printf '%s\n' 'kubectl wait --for=condition=available deployment/keyprovider -n trustee --timeout=120s'
printf '%s\n' '# Forward the key provider port to localhost so skopeo can reach it.'
printf '%s\n' 'kubectl port-forward -n trustee svc/keyprovider 50000:50000 &'
printf '%s\n' 'export PORT_FORWARD_PID=$!'
printf '%s\n' '# Give the port-forward a moment to establish the connection.'
printf '%s\n' 'sleep 3'
printf "${RESET}"

# Deploy the Key Broker Service.
kubectl apply -f k8s/kbs.yaml
# Deploy the key provider.
kubectl apply -f k8s/key-provider.yaml
# Wait for KBS to be ready.
kubectl wait --for=condition=available deployment/kbs -n trustee --timeout=120s
# Wait for the key provider to be ready.
kubectl wait --for=condition=available deployment/keyprovider -n trustee --timeout=120s
# Forward the key provider port to localhost so skopeo can reach it.
kubectl port-forward -n trustee svc/keyprovider 50000:50000 &
export PORT_FORWARD_PID=$!
# Give the port-forward a moment to establish the connection.
sleep 3

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Generate Signing Keys'
printf '%s\n' ''
printf '%s\n' 'Generate an Ed25519 key pair. The private key signs the image; the public key can be distributed'
printf '%s\n' 'to verify signatures without exposing the private key.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Generate the Ed25519 signing private key.'
printf '%s\n' 'openssl genpkey -algorithm ed25519 -out ./config/image-signing-key.pem'
printf '%s\n' '# Extract the corresponding public key.'
printf '%s\n' 'openssl pkey -in ./config/image-signing-key.pem -pubout -out ./config/public.pub'
printf "${RESET}"

# Generate the Ed25519 signing private key.
openssl genpkey -algorithm ed25519 -out ./config/image-signing-key.pem
# Extract the corresponding public key.
openssl pkey -in ./config/image-signing-key.pem -pubout -out ./config/public.pub

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Configure the registry to store signatures as sigstore OCI attachments:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Configure sigstore attachments for the registry.'
printf '%s\n' 'sudo mkdir -p /etc/containers/registries.d'
printf '%s\n' 'cat <<EOF | sudo tee /etc/containers/registries.d/default.yaml > /dev/null'
printf '%s\n' 'docker:'
printf '%s\n' '    ${REGISTRY}:'
printf '%s\n' '        use-sigstore-attachments: true'
printf '%s\n' 'EOF'
printf "${RESET}"

# Configure sigstore attachments for the registry.
sudo mkdir -p /etc/containers/registries.d
cat <<EOF | sudo tee /etc/containers/registries.d/default.yaml > /dev/null
docker:
    ${REGISTRY}:
        use-sigstore-attachments: true
EOF

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Create the Rust project (or reuse an existing one):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Create the Rust project in `hello-world` if it does not already exist.'
printf '%s\n' 'cargo new hello-world || echo "hello-world already exists - using existing one"'
printf "${RESET}"

# Create the Rust project in `hello-world` if it does not already exist.
cargo new hello-world || echo "hello-world already exists - using existing one"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t $IMAGE_NAME .'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push $IMAGE_NAME'
printf "${RESET}"

# Build the container image.
docker build -t $IMAGE_NAME .
# Push the container image to the registry.
docker push $IMAGE_NAME

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the pull secret already exists.'
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  # Load environment variables from the tplenv definition file.'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})'
printf '%s\n' '  # Create the Docker registry pull secret.'
printf '%s\n' '  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

# Check whether the pull secret already exists.
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Load environment variables from the tplenv definition file.
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-})
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Run the Native Application'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"'
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifest.job.yaml -n ${NAMESPACE}'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE} || echo "ok - no previous job that we need to delete"
# Apply the Kubernetes manifest.
kubectl apply -f manifest.job.yaml -n ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '# Show logs from the Kubernetes workload.'
printf '%s\n' 'kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job image-signing -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 8. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Before sending encrypted policies to CAS, attest CAS via the Kubernetes API:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Attest the CAS instance before sending encrypted policies.'
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."'
printf "${RESET}"

# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is OK if you first attested using *scone cas attest ..."

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 9. Register and Sign the Confidential Image'
printf '%s\n' ''
printf '%s\n' 'The `--signing-key` flag activates the encrypted-image flow: `scone-td-build` sconifies the image,'
printf '%s\n' 'then uses `skopeo` to encrypt the layers with the attestation-agent key provider and embed a'
printf '%s\n' 'Sigstore signature. The result is pushed to `${DESTINATION_IMAGE_NAME}-encrypted`.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Register, sign, and encrypt the confidential image.'
printf '%s\n' 'OCICRYPT_KEYPROVIDER_CONFIG=./config/ocicrypt.conf \'
printf '%s\n' '  scone-td-build register \'
printf '%s\n' '    --protected-image $IMAGE_NAME \'
printf '%s\n' '    --unprotected-image rust:latest \'
printf '%s\n' '    --manifest-env SCONE_PRODUCTION=0 \'
printf '%s\n' '    -s ./storage.json \'
printf '%s\n' '    --destination-image ${DESTINATION_IMAGE_NAME} \'
printf '%s\n' '    --signing-key ./config/image-signing-key.pem \'
printf '%s\n' '    --signing-passphrase-file ./config/empty-passphrase.txt \'
printf '%s\n' '    --repo-credentials ${REPO_CREDENTIALS} \'
printf '%s\n' '    --version ${SCONE_RUNTIME_VERSION} \'
printf '%s\n' '    ${CVM_MODE}'
printf "${RESET}"

# Register, sign, and encrypt the confidential image.
OCICRYPT_KEYPROVIDER_CONFIG=./config/ocicrypt.conf \
  scone-td-build register \
    --protected-image $IMAGE_NAME \
    --unprotected-image rust:latest \
    --manifest-env SCONE_PRODUCTION=0 \
    -s ./storage.json \
    --destination-image ${DESTINATION_IMAGE_NAME} \
    --signing-key ./config/image-signing-key.pem \
    --signing-passphrase-file ./config/empty-passphrase.txt \
    --repo-credentials ${REPO_CREDENTIALS} \
    --version ${SCONE_RUNTIME_VERSION} \
    ${CVM_MODE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 10. Verify Image Signature'
printf '%s\n' ''
printf '%s\n' 'Inspect the signed and encrypted image to confirm the Sigstore signature is attached:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Inspect the signed and encrypted image.'
printf '%s\n' 'skopeo inspect docker://${DESTINATION_IMAGE_NAME}-encrypted'
printf "${RESET}"

# Inspect the signed and encrypted image.
skopeo inspect docker://${DESTINATION_IMAGE_NAME}-encrypted

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 11. Transform the Kubernetes Manifest'
printf '%s\n' ''
printf '%s\n' 'Convert the native manifest into a sanitized confidential manifest:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Convert the native manifest into a confidential manifest.'
printf '%s\n' 'scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --manifest-env SCONE_HEAP=1G --spol --manifest-env SCONE_VERSION=1 --output-manifest-file manifest.job.sanitized.yaml ${CVM_MODE} ${SCONE_ENCLAVE}'
printf "${RESET}"

# Convert the native manifest into a confidential manifest.
scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --manifest-env SCONE_HEAP=1G --spol --manifest-env SCONE_VERSION=1 --output-manifest-file manifest.job.sanitized.yaml ${CVM_MODE} ${SCONE_ENCLAVE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Update the manifest to reference the signed and encrypted image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Replace the protected image reference with the signed and encrypted variant.'
printf '%s\n' 'sed "s|image: ${DESTINATION_IMAGE_NAME}|image: ${DESTINATION_IMAGE_NAME}-encrypted|g" manifest.job.sanitized.yaml > manifest.job.signed.yaml'
printf "${RESET}"

# Replace the protected image reference with the signed and encrypted variant.
sed "s|image: ${DESTINATION_IMAGE_NAME}|image: ${DESTINATION_IMAGE_NAME}-encrypted|g" manifest.job.sanitized.yaml > manifest.job.signed.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 12. Deploy the Signed Confidential Application'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the signed confidential manifest.'
printf '%s\n' 'kubectl apply -f manifest.job.signed.yaml -n ${NAMESPACE}'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '# Show logs from the Kubernetes workload.'
printf '%s\n' 'kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

# Apply the signed confidential manifest.
kubectl apply -f manifest.job.signed.yaml -n ${NAMESPACE}
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=complete job/image-signing -n ${NAMESPACE} --timeout=300s
# Show logs from the Kubernetes workload.
kubectl logs job/image-signing -n ${NAMESPACE} --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 13. Uninstall `image-signing`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete job image-signing -n ${NAMESPACE} || true'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s'
printf '%s\n' '# Stop the key provider port-forward.'
printf '%s\n' 'kill ${PORT_FORWARD_PID} 2>/dev/null || true'
printf '%s\n' '# Delete the key provider.'
printf '%s\n' 'kubectl delete -f k8s/key-provider.yaml'
printf '%s\n' '# Delete the Key Broker Service.'
printf '%s\n' 'kubectl delete -f k8s/kbs.yaml'
printf '%s\n' '# Return to the previous working directory.'
printf '%s\n' 'popd'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete job image-signing -n ${NAMESPACE} || true
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=image-signing -n ${NAMESPACE} --timeout=300s
# Stop the key provider port-forward.
kill ${PORT_FORWARD_PID} 2>/dev/null || true
# Delete the key provider.
kubectl delete -f k8s/key-provider.yaml
# Delete the Key Broker Service.
kubectl delete -f k8s/kbs.yaml
# Return to the previous working directory.
popd

printf "${VIOLET}"
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
printf "${RESET}"

