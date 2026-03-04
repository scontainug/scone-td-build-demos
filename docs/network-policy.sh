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
printf '%s\n' '# NetworkPolicy'
printf '%s\n' ''
printf '%s\n' 'This guide shows how to build, deploy, and test the **NetworkPolicy demo** using `k8s-scone`. You will build client and server images, generate SCONE-protected images, apply the Kubernetes manifests, and verify that everything works as expected.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧱 Normal Setup'
printf '%s\n' ''
printf '%s\n' 'Make sure you have the following tools installed and configured:'
printf '%s\n' ''
printf '%s\n' '- Docker'
printf '%s\n' '- Kubernetes cluster (with `kubectl` configured)'
printf '%s\n' '- `scone-td-build` built locally'
printf '%s\n' '- Access to a container registry where you can push images'
printf '%s\n' ''
printf '%s\n' 'Navigate to the NetworkPolicy demo directory:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
cd network-policy
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🐳 Build Images'
printf '%s\n' ''
printf '%s\n' 'First, define the names of the Docker images that will be used for the demo. Hence, `tplenv` will now ask for all environment variables described in `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '### Build and push the base images'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
docker build -t $SERVER_IMAGE "server/"
EOF
)"
pe "$(cat <<'EOF'
docker build -t $CLIENT_IMAGE "client/"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
docker push $SERVER_IMAGE
EOF
)"
pe "$(cat <<'EOF'
docker push $CLIENT_IMAGE
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Generate SCONE images'
printf '%s\n' ''
printf '%s\n' 'Create the SCONE configuration from the template and apply it using `k8s-scone`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"
EOF
)"
pe "$(cat <<'EOF'
tplenv --file "./scone.template.yaml" --output "./scone.yaml"
EOF
)"
pe "$(cat <<'EOF'
scone-td-build from -y ./scone.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This will generate SCONE-protected variants of both images.'
printf '%s\n' ''
printf '%s\n' 'Push the generated SCONE images:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
docker push $SERVER_IMAGE-scone
EOF
)"
pe "$(cat <<'EOF'
docker push $CLIENT_IMAGE-scone
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🚀 Apply Kubernetes Manifests'
printf '%s\n' ''
printf '%s\n' 'Deploy the application and NetworkPolicy configuration to the cluster:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f "demo/examples/networkPolicy/manifest.prod.sanitized.yaml"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Wait until all pods are running before continuing.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## ✅ Test the Setup'
printf '%s\n' ''
printf '%s\n' 'Forward the server service port to your local machine:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl port-forward svc/barad-dur 3000 &
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Send a request to the server:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
curl localhost:3000/db-query
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '### Expected Result'
printf '%s\n' ''
printf '%s\n' 'The request should return a **random 7-character password**, confirming that:'
printf '%s\n' ''
printf '%s\n' '- The application is running correctly'
printf '%s\n' '- The SCONE-protected images are working'
printf '%s\n' '- NetworkPolicy rules allow the intended traffic'
printf "%b" "$RESET"

