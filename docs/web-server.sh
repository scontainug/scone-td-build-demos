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
pe 'pushd web-server'
pe 'export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""'

pe 'eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'

pe '# attest the CAS - to ensure that we know the correct session encryption key'
pe 'kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}'

pe '# customize the job manifest'
pe 'tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml'

pe '# Build the Scone image for the demo client'
pe 'docker build -t ${IMAGE_NAME} .'
pe ''
pe '# Push it to the registry'
pe 'docker push ${IMAGE_NAME}'

pe 'if [ ! -f identity.pem ]; then'
pe '  echo "Generating identity.pem ..."'
pe '  openssl genrsa -3 -out identity.pem 3072'
pe 'else'
pe '  echo "identity.pem already exists."'
pe 'fi'

pe 'scone-td-build register \'
pe '    --protected-image ${IMAGE_NAME} \'
pe '    --unprotected-image ${IMAGE_NAME} \'
pe '    --destination-image ${DESTINATION_IMAGE_NAME} \'
pe '    --push \'
pe '    -s ./storage.json \'
pe '    --enforce /app/web-server \'
pe '    --version ${SCONE_VERSION}'

pe '# Make sure web-server does not yet run'
pe 'kubectl delete deployment web-server || echo "ok - no web-server deployment yet"'
pe 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
pe 'kill $(cat /tmp/pf-8000.pid) || true'

pe 'kubectl apply -f manifest.yaml'
pe 'kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
pe ''
pe '# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps'
pe '# Use this command in another terminal or add `&` at the end of the command to run in the background'
pe 'kubectl port-forward deployment/web-server 8000:8000 &'
pe 'echo $! > /tmp/pf-8000.pid'
pe ''
pe 'retry-spinner -- curl http://localhost:8000/env/MY_POD_IP'
pe './test.sh'
pe ''
pe 'kubectl delete -f manifest.yaml'
pe 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
pe ''
pe '# Close the port forward after the execution'
pe 'kill $(cat /tmp/pf-8000.pid) || true'
pe 'rm /tmp/pf-8000.pid'

pe 'scone-td-build apply \'
pe '    -f manifest.yaml \'
pe '    -c ${CAS_NAME}.${CAS_NAMESPACE} \'
pe '    -s ./storage.json \'
pe '    --manifest-env SCONE_SYSLIBS=1 \'
pe '    --manifest-env SCONE_VERSION=1 \'
pe '    --session-env SCONE_VERSION=1 \'
pe '    --version ${SCONE_VERSION} -p'

pe 'kubectl apply -f manifest.cleaned.yaml'

pe 'kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
pe '# being ready does not mean that port is available'
pe 'sleep 20'
pe ''
pe 'kubectl port-forward deployment/web-server 8000:8000 &'
pe '# we keep to PID to be able to delete the port-forward'
pe 'echo $! > /tmp/pf-8000.pid'

pe '# Test path - result in error'
pe 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path'
pe ''
pe '# Test gen'
pe 'retry-spinner -- curl http://localhost:8000/gen'
pe ''
pe '# Test env'
pe './test.sh'

pe 'kubectl delete -f manifest.cleaned.yaml'
pe 'kill $(cat /tmp/pf-8000.pid) || true'
pe 'rm /tmp/pf-8000.pid'
pe 'popd'

