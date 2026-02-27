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

pe 'pushd configmap'
pe '# ensure that the following is not set'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

pe 'eval $(tplenv --file environment-variables.md --create-values-file  --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

pe 'pushd folder-reader'
pe 'docker build -t ${DEMO_IMAGE} .'
pe 'docker push ${DEMO_IMAGE}'
pe ''
pe 'popd'

pe 'export SIGNER="$(scone self show-session-signing-key)"'

pe 'tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml  --indent'
pe 'tplenv --file scone.template.yaml --create-values-file --output manifests/scone.yaml  --indent'

pe 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
pe '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
pe 'else'
pe '  echo "Secret ${IMAGE_PULL_SECRET_NAME} not exist - creating now."'
pe '  # ask user for the credentials for accessing the registry'
pe '  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )'
pe '  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
pe 'fi'

pe 'kubectl apply -f manifests/manifest.yaml'
pe ''
pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-1'
pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-2'
pe ''
pe '# Clean up native app'
pe 'kubectl delete -f manifests/manifest.yaml'

pe 'scone-td-build from -y manifests/scone.yaml'

pe 'kubectl apply -f manifests/manifest.prod.sanitized.yaml'

pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-1 --follow'
pe 'retry-spinner -- kubectl logs job/my-rust-app -c reader-2 --follow'

pe 'kubectl delete -f manifests/manifest.prod.sanitized.yaml'

