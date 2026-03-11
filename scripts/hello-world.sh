#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# SCONE: Hello World'
printf '%s\n' ''
printf '%s\n' '[![Hello World Example](../docs/hello-world.gif)](../docs/hello-world.mp4)'
printf '%s\n' ''
printf '%s\n' 'This example shows how to build a simple cloud-native `hello-world` application in Rust, run it natively in Kubernetes, and then deploy a confidential version with SCONE.'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster with SGX or CVM support'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
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
printf '%s\n' 'pushd hello-world'
printf '%s\n' 'rm -f storage.json || true'
printf "${RESET}"

pushd hello-world
rm -f storage.json || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This example uses the following variables.'
printf '%s\n' ''
printf '%s\n' 'For the native deployment:'
printf '%s\n' ''
printf '%s\n' '- `$IMAGE_NAME` - Name of the native container image for `hello-world`'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` - Pull secret name for this image (default: `sconeapps`)'
printf '%s\n' ''
printf '%s\n' 'For the confidential deployment:'
printf '%s\n' ''
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` - Name of the confidential image'
printf '%s\n' '- `$SCONE_VERSION` - SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE` - CAS Kubernetes namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` - CAS Kubernetes name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE` - Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` - In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' ''
printf '%s\n' 'Defaults are stored in `Values.yaml`. We use [`tplenv`](https://github.com/scontainug/tplenv) to confirm or override values:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate the job manifest with the selected image and pull-secret values:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml'
printf "${RESET}"

tplenv --file manifest.job.template.yaml --create-values-file --output manifest.job.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 3. Build the Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Create the Rust project (or reuse an existing one):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cargo new hello-world || echo "Hello World already exists - using existing one"'
printf "${RESET}"

cargo new hello-world || echo "Hello World already exists - using existing one"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Build and push the image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'docker build -t $IMAGE_NAME .'
printf '%s\n' 'docker push $IMAGE_NAME'
printf "${RESET}"

docker build -t $IMAGE_NAME .
docker push $IMAGE_NAME

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
printf '%s\n' '## 5. Run the Native Hello-World Application'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete job hello-world || echo "ok - no previous job that we need to delete"'
printf '%s\n' 'kubectl apply -f manifest.job.yaml'
printf "${RESET}"

kubectl delete job hello-world || echo "ok - no previous job that we need to delete"
kubectl apply -f manifest.job.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait for completion and stream logs:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl wait --for=condition=complete job/hello-world --timeout=300s'
printf '%s\n' 'kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

kubectl wait --for=condition=complete job/hello-world --timeout=300s
kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Clean up:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete job hello-world'
printf '%s\n' 'kubectl wait --for=delete pod -l app=hello-world --timeout=300s'
printf "${RESET}"

kubectl delete job hello-world
kubectl wait --for=delete pod -l app=hello-world --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 6. Attest SCONE CAS'
printf '%s\n' ''
printf '%s\n' 'Before sending encrypted policies to CAS, attest CAS via the Kubernetes API:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is ok if you first attested using *scone cas attest ..."'
printf "${RESET}"

kubectl scone cas attest --namespace ${CAS_NAMESPACE} ${CAS_NAME} -C -G -S || echo "Attestation failed: This is ok if you first attested using *scone cas attest ..."

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If attestation fails, inspect the command output for detected vulnerabilities and suggested tolerance flags.'
printf '%s\n' ''
printf '%s\n' '## 7. Register the Confidential Image'
printf '%s\n' ''
printf '%s\n' 'Register the image for confidential execution:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}'
printf "${RESET}"

scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This creates a protected image (or uses `--destination-image` if provided) and decouples your deployment from upstream image changes.'
printf '%s\n' ''
printf '%s\n' '## 8. Transform the Kubernetes Manifest'
printf '%s\n' ''
printf '%s\n' 'Convert the native manifest into a sanitized confidential manifest:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --spol --manifest-env SCONE_VERSION=1 ${CVM_MODE} ${SCONE_ENCLAVE}'
printf "${RESET}"

scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0 --spol --manifest-env SCONE_VERSION=1 ${CVM_MODE} ${SCONE_ENCLAVE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 9. Deploy the Confidential Manifest'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.job.cleaned.yaml'
printf '%s\n' 'kubectl wait --for=condition=complete job/hello-world --timeout=300s'
printf '%s\n' 'kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

kubectl apply -f manifest.job.cleaned.yaml
kubectl wait --for=condition=complete job/hello-world --timeout=300s
kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 10. Uninstall `hello-world`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete job hello-world'
printf '%s\n' 'kubectl wait --for=delete pod -l app=hello-world --timeout=300s'
printf '%s\n' 'popd'
printf "${RESET}"

kubectl delete job hello-world
kubectl wait --for=delete pod -l app=hello-world --timeout=300s
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## Automation'
printf '%s\n' ''
printf '%s\n' 'You can run this workflow with:'
printf '%s\n' ''
printf '%s\n' './scripts/hello-world.sh'
printf '%s\n' ''
printf '%s\n' 'It asks for user input unless you set:'
printf '%s\n' ''
printf '%s\n' 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"'
printf '%s\n' ''
printf '%s\n' 'This uses values from `hello-world/Values.yaml` and skips interactive prompts. By default, this variable is set to `--force`, which prompts for confirmation of current values.'
printf '%s\n' ''
printf '%s\n' 'If you update commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.'
printf "${RESET}"

