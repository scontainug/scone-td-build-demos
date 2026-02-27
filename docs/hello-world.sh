#!/usr/bin/env bash

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
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

pe '# Ensure we are in the correct directory. Assumption, we start at directory `scone-td-build-demos`'
pe 'pushd hello-world'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

pe 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

pe '# attest the CAS - to ensure that we know the correct session encryption key'
pe 'kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}'

pe '# customize the job manifest'
pe 'tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml'

pe '# create the hello-world application'
pe 'cargo new hello-world || echo "Hello World already exists - using existing one"'

pe '# build the hello-world app in a Container'
pe 'docker build -t $IMAGE_NAME .'

pe 'scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}'

pe 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
pe '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
pe 'else'
pe '  echo "Secret ${IMAGE_PULL_SECRET_NAME} not exist - creating now."'
pe '  # ask user for the credentials for accessing the registry'
pe '  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )'
pe '  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
pe 'fi'

pe 'scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  ${CVM_MODE} ${SCONE_ENCLAVE}'

pe '# Ensure that previous run is not running anymore'
pe 'kubectl delete job hello-world || echo "ok - no previous job that we need to delete"'
pe 'kubectl apply -f manifest.job.cleaned.yaml'

pe 'retry-spinner -- kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps'

pe 'kubectl delete job hello-world '
pe 'popd'

