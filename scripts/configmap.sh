#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

show_help() {
  cat <<USAGE
Usage: $0 [--help]

Runs shell commands extracted from configmap/README.md.

Options:
  --help  Show this help message and exit.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
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

printf "${VIOLET}"
printf '%s\n' '# SCONE ConfigMap Example: Secure Configuration Data in Kubernetes'
printf '%s\n' ''
printf '%s\n' 'This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a SCONE-enabled Rust application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '[![ConfigMap Example](../docs/configmap.gif)](../docs/configmap.mp4)'
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
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Assume you start in `scone-td-build-demos` and switch into this demo directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'pushd configmap'
printf '%s\n' 'rm -f configmap-example.json || true'
printf "${RESET}"

pushd configmap
rm -f configmap-example.json || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:'
printf '%s\n' ''
printf '%s\n' '- `$DEMO_IMAGE` - Name of the native image to deploy'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'export SIGNER="$(scone self show-session-signing-key)"'
printf "${RESET}"

export SIGNER="$(scone self show-session-signing-key)"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 4. Build the Native Rust Image'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'pushd folder-reader'
printf '%s\n' 'docker build -t ${DEMO_IMAGE} .'
printf '%s\n' 'docker push ${DEMO_IMAGE}'
printf '%s\n' 'popd'
printf "${RESET}"

pushd folder-reader
docker build -t ${DEMO_IMAGE} .
docker push ${DEMO_IMAGE}
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 5. Render the Manifests'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent'
printf '%s\n' 'tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml --indent'
printf "${RESET}"

tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml --indent

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Before applying, confirm that image values were substituted correctly.'
printf '%s\n' ''
printf '%s\n' '## 6. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'If you need a pull secret for native and confidential images, create it when missing.'
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
printf '%s\n' '## 7. Deploy the Native App (Optional)'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifests/manifest.yaml'
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
printf '%s\n' 'Your containers should print content from the mounted ConfigMap files.'
printf '%s\n' ''
printf '%s\n' '## 8. Prepare and Apply the SCONE Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build from -y manifests/scone.yaml'
printf "${RESET}"

scone-td-build from -y manifests/scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Generates a SCONE session'
printf '%s\n' '- Attaches the session to your manifest'
printf '%s\n' '- Produces `manifests/manifest.prod.sanitized.yaml`'
printf '%s\n' ''
printf '%s\n' '## 9. Deploy the SCONE-Protected App'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifests/manifest.prod.sanitized.yaml'
printf "${RESET}"

kubectl apply -f manifests/manifest.prod.sanitized.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 10. View Logs'
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
printf '%s\n' '## 11. Clean Up'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f manifests/manifest.prod.sanitized.yaml'
printf '%s\n' 'popd'
printf "${RESET}"

kubectl delete -f manifests/manifest.prod.sanitized.yaml
popd

