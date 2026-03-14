#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from web-server/README.md.

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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Enter `web-server` and remember the previous directory.'
printf '%s\n' 'pushd web-server'
printf '%s\n' '# Remove `storage.json` if it exists.'
printf '%s\n' 'rm storage.json || true'
printf "${RESET}"

# Enter `web-server` and remember the previous directory.
pushd web-server
# Remove `storage.json` if it exists.
rm storage.json || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. `tplenv` asks whether to keep them and sets:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native `web-server` image'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Load environment variables from the tplenv definition file.'
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)'
printf "${RESET}"

# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Attest CAS before sending encrypted policies:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Attest the CAS instance before sending encrypted policies.'
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is ok if you first attested using *scone cas attest ..."'
printf "${RESET}"

# Attest the CAS instance before sending encrypted policies.
kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is ok if you first attested using *scone cas attest ..."

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, review the output for detected issues and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' 'Render the manifest template:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file manifest.template.yaml --create-values-file --output manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'If the pull secret does not exist yet, create it using registry credentials.'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` - Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` - Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})'
printf '%s\n' '  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Build and Register the Image'
printf '%s\n' ''
printf '%s\n' 'Build and push the native image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t ${IMAGE_NAME} .'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push ${IMAGE_NAME}'
printf "${RESET}"

# Build the container image.
docker build -t ${IMAGE_NAME} .
# Push the container image to the registry.
docker push ${IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate a signing key for confidential binaries if needed:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Check whether the signing key needs to be generated.'
printf '%s\n' 'if [ ! -f identity.pem ]; then'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  # Generate the signing key for confidential binaries.'
printf '%s\n' '  openssl genrsa -3 -out identity.pem 3072'
printf '%s\n' 'else'
printf '%s\n' '  # Print a status message.'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

# Check whether the signing key needs to be generated.
if [ ! -f identity.pem ]; then
  # Print a status message.
  echo "Generating identity.pem ..."
  # Generate the signing key for confidential binaries.
  openssl genrsa -3 -out identity.pem 3072
else
  # Print a status message.
  echo "identity.pem already exists."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Register the image with `scone-td-build`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Register the image for confidential execution.'
printf '%s\n' 'scone-td-build register \'
printf '%s\n' '  --protected-image ${IMAGE_NAME} \'
printf '%s\n' '  --unprotected-image ${IMAGE_NAME} \'
printf '%s\n' '  --destination-image ${DESTINATION_IMAGE_NAME} \'
printf '%s\n' '  --push \'
printf '%s\n' '  -s ./storage.json \'
printf '%s\n' '  --enforce /app/web-server \'
printf '%s\n' '  --version ${SCONE_RUNTIME_VERSION}'
printf "${RESET}"

# Register the image for confidential execution.
scone-td-build register \
  --protected-image ${IMAGE_NAME} \
  --unprotected-image ${IMAGE_NAME} \
  --destination-image ${DESTINATION_IMAGE_NAME} \
  --push \
  -s ./storage.json \
  --enforce /app/web-server \
  --version ${SCONE_RUNTIME_VERSION}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Test the Native Manifest (Optional)'
printf '%s\n' ''
printf '%s\n' 'Clean up previous runs first:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete deployment web-server || echo "ok - no web-server deployment yet"'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server --timeout=240s || echo "ok - no web-server deployment yet"'
printf '%s\n' '# Stop the previous background process if it is still running.'
printf '%s\n' 'kill $(cat /tmp/pf-8000.pid) || true'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete deployment web-server || echo "ok - no web-server deployment yet"
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server --timeout=240s || echo "ok - no web-server deployment yet"
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-8000.pid) || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Deploy and test:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifest.yaml'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
printf '%s\n' '# Start a local port-forward to the Kubernetes workload.'
printf '%s\n' 'kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid'
printf '%s\n' ''
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/env/MY_POD_IP'
printf '%s\n' '# Run the demo test script.'
printf '%s\n' './test.sh'
printf '%s\n' ''
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f manifest.yaml'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
printf '%s\n' '# Stop the previous background process if it is still running.'
printf '%s\n' 'kill $(cat /tmp/pf-8000.pid) || true'
printf '%s\n' '# Remove `/tmp/pf-8000.pid` if it exists.'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f manifest.yaml
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# Start a local port-forward to the Kubernetes workload.
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
# Run the demo test script.
./test.sh

# Delete the Kubernetes resource if it exists.
kubectl delete -f manifest.yaml
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=delete pod -l app=web-server --timeout=240s
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-8000.pid) || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 7. Convert the Manifest'
printf '%s\n' ''
printf '%s\n' 'If you want to inspect registration details, see [register-image](../../../register-image.md).'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Convert the native manifest into a confidential manifest.'
printf '%s\n' 'scone-td-build apply \'
printf '%s\n' '  -f manifest.yaml \'
printf '%s\n' '  -c ${CAS_NAME}.${CAS_NAMESPACE} \'
printf '%s\n' '  -s ./storage.json \'
printf '%s\n' '  --spol \'
printf '%s\n' '  --manifest-env SCONE_SYSLIBS=1 \'
printf '%s\n' '  --manifest-env SCONE_VERSION=1 \'
printf '%s\n' '  --session-env SCONE_VERSION=1 \'
printf '%s\n' '  --version ${SCONE_RUNTIME_VERSION} -p'
printf "${RESET}"

# Convert the native manifest into a confidential manifest.
scone-td-build apply \
  -f manifest.yaml \
  -c ${CAS_NAME}.${CAS_NAMESPACE} \
  -s ./storage.json \
  --spol \
  --manifest-env SCONE_SYSLIBS=1 \
  --manifest-env SCONE_VERSION=1 \
  --session-env SCONE_VERSION=1 \
  --version ${SCONE_RUNTIME_VERSION} -p

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 8. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f manifest.cleaned.yaml'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f manifest.cleaned.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'For the next step, you need a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '## 9. Run the Demo'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
printf '%s\n' '# A ready pod does not always mean the port is immediately available.'
printf '%s\n' '# Wait briefly for the service to become reachable.'
printf '%s\n' 'sleep 20'
printf '%s\n' '# Start a local port-forward to the Kubernetes workload.'
printf '%s\n' 'kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid'
printf "${RESET}"

# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# A ready pod does not always mean the port is immediately available.
# Wait briefly for the service to become reachable.
sleep 20
# Start a local port-forward to the Kubernetes workload.
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send test requests:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path'
printf '%s\n' '# Retry the wrapped command until it succeeds or reaches the retry limit.'
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/gen'
printf '%s\n' '# Run the demo test script.'
printf '%s\n' './test.sh'
printf "${RESET}"

# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- curl http://localhost:8000/gen
# Run the demo test script.
./test.sh

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 10. Uninstall the Demo'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f manifest.cleaned.yaml'
printf '%s\n' '# Stop the previous background process if it is still running.'
printf '%s\n' 'kill $(cat /tmp/pf-8000.pid) || true'
printf '%s\n' '# Remove `/tmp/pf-8000.pid` if it exists.'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf '%s\n' '# Return to the previous working directory.'
printf '%s\n' 'popd'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete -f manifest.cleaned.yaml
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-8000.pid) || true
# Remove `/tmp/pf-8000.pid` if it exists.
rm /tmp/pf-8000.pid
# Return to the previous working directory.
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This demo provides a simple but functional Rust web service that you can extend as needed.'
printf "${RESET}"

