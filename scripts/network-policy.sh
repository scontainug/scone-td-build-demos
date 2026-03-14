#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs shell commands extracted from network-policy/README.md.

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
printf '%s\n' '# NetworkPolicy'
printf '%s\n' ''
printf '%s\n' 'This guide explains how to build, deploy, and test the **NetworkPolicy demo** with `scone-td-build`. You will build client and server images, generate SCONE-protected images, apply Kubernetes manifests, and verify the result.'
printf '%s\n' ''
printf '%s\n' '[![Network Policy Example](../docs/network-policy.gif)](../docs/network-policy.mp4)'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' 'Make sure you have:'
printf '%s\n' ''
printf '%s\n' '- Docker'
printf '%s\n' '- A Kubernetes cluster with `kubectl` configured'
printf '%s\n' '- `tplenv`'
printf '%s\n' '- `scone-td-build` built locally'
printf '%s\n' '- Access to a container registry where you can push images'
printf '%s\n' ''
printf '%s\n' 'Switch to the demo directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Change into `network-policy`.'
printf '%s\n' 'cd network-policy'
printf '%s\n' '# Remove `netshield.json` if it exists.'
printf '%s\n' 'rm -f netshield.json || true'
printf "${RESET}"

# Change into `network-policy`.
cd network-policy
# Remove `netshield.json` if it exists.
rm -f netshield.json || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 2. Build Images'
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Export the required environment variable for the next steps.'
printf '%s\n' 'export SIGNER="$(scone self show-session-signing-key)"'
printf "${RESET}"

# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Initialize environment variables from `environment-variables.md` using `tplenv`:'
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
printf '%s\n' 'Build and push native images:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t $SERVER_IMAGE "server/"'
printf '%s\n' '# Build the container image.'
printf '%s\n' 'docker build -t $CLIENT_IMAGE "client/"'
printf '%s\n' ''
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push $SERVER_IMAGE'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push $CLIENT_IMAGE'
printf "${RESET}"

# Build the container image.
docker build -t $SERVER_IMAGE "server/"
# Build the container image.
docker build -t $CLIENT_IMAGE "client/"

# Push the container image to the registry.
docker push $SERVER_IMAGE
# Push the container image to the registry.
docker push $CLIENT_IMAGE

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Generate SCONE Images'
printf '%s\n' ''
printf '%s\n' 'Create SCONE config files from templates, then run `scone-td-build`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"'
printf '%s\n' '# Render the template with the selected values.'
printf '%s\n' 'tplenv --file "./scone.template.yaml" --output "./scone.yaml"'
printf '%s\n' '# Generate the confidential image and sanitized manifest from the SCONE configuration.'
printf '%s\n' 'scone-td-build from -y ./scone.yaml'
printf "${RESET}"

# Render the template with the selected values.
tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"
# Render the template with the selected values.
tplenv --file "./scone.template.yaml" --output "./scone.yaml"
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y ./scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Push the generated SCONE images:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push $SERVER_IMAGE-scone'
printf '%s\n' '# Push the container image to the registry.'
printf '%s\n' 'docker push $CLIENT_IMAGE-scone'
printf "${RESET}"

# Push the container image to the registry.
docker push $SERVER_IMAGE-scone
# Push the container image to the registry.
docker push $CLIENT_IMAGE-scone

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Apply Kubernetes Manifests'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Apply the Kubernetes manifest.'
printf '%s\n' 'kubectl apply -f "manifest.prod.sanitized.yaml"'
printf "${RESET}"

# Apply the Kubernetes manifest.
kubectl apply -f "manifest.prod.sanitized.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait until all pods are running before continuing.'
printf '%s\n' ''
printf '%s\n' '## 5. Test the Setup'
printf '%s\n' ''
printf '%s\n' 'Wait for pods and port-forward the server service:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="server" --timeout=300s'
printf '%s\n' '# Wait for the Kubernetes resource to reach the expected state.'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="client" --timeout=300s'
printf '%s\n' '# A ready pod does not always mean the port is immediately available.'
printf '%s\n' '# Wait briefly for the service to become reachable.'
printf '%s\n' 'sleep 10'
printf '%s\n' ''
printf '%s\n' '# Start a local port-forward to the Kubernetes workload.'
printf '%s\n' 'kubectl port-forward svc/barad-dur 3000 & echo $! > /tmp/pf-3000.pid'
printf "${RESET}"

# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="server" --timeout=300s
# Wait for the Kubernetes resource to reach the expected state.
kubectl wait --for=condition=Ready pod -l app="client" --timeout=300s
# A ready pod does not always mean the port is immediately available.
# Wait briefly for the service to become reachable.
sleep 10

# Start a local port-forward to the Kubernetes workload.
kubectl port-forward svc/barad-dur 3000 & echo $! > /tmp/pf-3000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send requests:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Send a test request to the demo service endpoint.'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query'
printf '%s\n' '# Send a test request to the demo service endpoint.'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query'
printf "${RESET}"

# Send a test request to the demo service endpoint.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
# Send a test request to the demo service endpoint.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Expected result: a random 7-character password, which confirms:'
printf '%s\n' ''
printf '%s\n' '- The application is running correctly'
printf '%s\n' '- SCONE-protected images are working'
printf '%s\n' '- NetworkPolicy rules allow intended traffic'
printf '%s\n' ''
printf '%s\n' '## 6. Uninstall the Demo'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Delete the Kubernetes resource if it exists.'
printf '%s\n' 'kubectl delete -f manifest.prod.sanitized.yaml'
printf '%s\n' '# Stop the previous background process if it is still running.'
printf '%s\n' 'kill $(cat /tmp/pf-3000.pid) || true'
printf '%s\n' '# Remove `/tmp/pf-3000.pid` if it exists.'
printf '%s\n' 'rm /tmp/pf-3000.pid'
printf '%s\n' '# Return to the previous working directory.'
printf '%s\n' 'cd -'
printf "${RESET}"

# Delete the Kubernetes resource if it exists.
kubectl delete -f manifest.prod.sanitized.yaml
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-3000.pid) || true
# Remove `/tmp/pf-3000.pid` if it exists.
rm /tmp/pf-3000.pid
# Return to the previous working directory.
cd -

