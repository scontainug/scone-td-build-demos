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

Runs a demo-style shell script generated from flask-redis-netshield/README.md.

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
printf '%s\n' '# Flask Redis Netshield'
printf '%s\n' ''
printf '%s\n' 'A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.'
printf '%s\n' 'This guide walks through deploying the **native** version first, running integration tests, and then building and deploying the **confidential** (SCONE) version before testing it again.'
printf '%s\n' ''
printf '%s\n' '[![Flask Redis Netshield Example](../docs/flask-redis-netshield.gif)](../docs/flask-redis-netshield.mp4)'
printf '%s\n' ''
printf '%s\n' '## Project Structure'
printf '%s\n' ''
printf '%s\n' 'flask-redis-netshield/'
printf '%s\n' '├── app.py                       # Flask application'
printf '%s\n' '├── Dockerfile                   # Flask image build'
printf '%s\n' '├── requirements.txt             # Python dependencies'
printf '%s\n' '├── scone.template.yaml          # SCONE confidential build template'
printf '%s\n' '├── environment-variables.md     # tplenv variable definitions'
printf '%s\n' '├── registry.credentials.md      # tplenv registry credential definitions'
printf '%s\n' '├── k8s/'
printf '%s\n' '│   └── manifest.template.yaml   # Redis + Flask API deployment template'
printf '%s\n' '└── README.md'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Prerequisites'
printf '%s\n' ''
printf '%s\n' '- `kubectl` configured for your cluster'
printf '%s\n' '- `docker` with access to a registry your cluster can pull from'
printf '%s\n' '- `openssl`, `tplenv`, and `envsubst` available in your shell'
printf '%s\n' '- `scone-td-build` binary'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 1 — Native Deployment'
printf '%s\n' ''
printf '%s\n' '### Step 1. Generate TLS certificates'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Change into `flask-redis-netshield`.
EOF
)"
pe "$(cat <<'EOF'
cd flask-redis-netshield
EOF
)"
pe "$(cat <<'EOF'
# Create `certs` if it does not already exist.
EOF
)"
pe "$(cat <<'EOF'
mkdir -p certs
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# CA
EOF
)"
pe "$(cat <<'EOF'
# Generate the certificate authority private key.
EOF
)"
pe "$(cat <<'EOF'
openssl genrsa -out certs/redis-ca.key 4096
EOF
)"
pe "$(cat <<'EOF'
# Create a self-signed certificate.
EOF
)"
pe "$(cat <<'EOF'
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Redis server cert
EOF
)"
pe "$(cat <<'EOF'
# Generate the Redis server private key.
EOF
)"
pe "$(cat <<'EOF'
openssl genrsa -out certs/redis.key 2048
EOF
)"
pe "$(cat <<'EOF'
# Create a certificate signing request.
EOF
)"
pe "$(cat <<'EOF'
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"
EOF
)"
pe "$(cat <<'EOF'
# Sign the certificate with the certificate authority.
EOF
)"
pe "$(cat <<'EOF'
openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Flask server cert
EOF
)"
pe "$(cat <<'EOF'
# Generate the Flask server private key.
EOF
)"
pe "$(cat <<'EOF'
openssl genrsa -out certs/flask.key 2048
EOF
)"
pe "$(cat <<'EOF'
# Create a certificate signing request.
EOF
)"
pe "$(cat <<'EOF'
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"
EOF
)"
pe "$(cat <<'EOF'
# Sign the certificate with the certificate authority.
EOF
)"
pe "$(cat <<'EOF'
openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Client cert (used by Flask to connect to Redis)
EOF
)"
pe "$(cat <<'EOF'
# Generate the client private key.
EOF
)"
pe "$(cat <<'EOF'
openssl genrsa -out certs/client.key 2048
EOF
)"
pe "$(cat <<'EOF'
# Create a certificate signing request.
EOF
)"
pe "$(cat <<'EOF'
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"
EOF
)"
pe "$(cat <<'EOF'
# Sign the certificate with the certificate authority.
EOF
)"
pe "$(cat <<'EOF'
openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/client.crt -days 365 -sha256
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '| File | Used by | Purpose |'
printf '%s\n' '|---|---|---|'
printf '%s\n' '| `redis-ca.crt` | Both | CA that signed all certs |'
printf '%s\n' '| `redis.crt` / `redis.key` | Redis | Redis server cert/key |'
printf '%s\n' '| `flask.crt` / `flask.key` | Flask | Flask HTTPS server cert/key |'
printf '%s\n' '| `client.crt` / `client.key` | Flask | mTLS client cert for Redis |'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 2. Collect environment variables and build the Docker image'
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Export the required environment variable for the next steps.
EOF
)"
pe "$(cat <<'EOF'
export SIGNER="$(scone self show-session-signing-key)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then let `tplenv` query all environment variables used by this example:'
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
printf '%s\n' 'Then build and push the native Docker image:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t ${IMAGE_NAME} .
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push ${IMAGE_NAME}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 3. Create the namespace'
printf '%s\n' ''
printf '%s\n' 'We try to ensure the namespace exists. This may fail when running in a container that is already in the target namespace, so we ignore that failure.'
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
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 4. Generate and inspect secret manifests'
printf '%s\n' ''
printf '%s\n' 'Generate the secret YAML files locally so you can inspect them before applying:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the Kubernetes secret manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl create secret generic redis-tls \
  --namespace ${NAMESPACE} \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Generate the Kubernetes secret manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl create secret generic flask-tls \
  --namespace ${NAMESPACE} \
  --from-file=flask.crt=certs/flask.crt \
  --from-file=flask.key=certs/flask.key \
  --from-file=client.crt=certs/client.crt \
  --from-file=client.key=certs/client.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Review the files in `k8s/`, then apply them:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f k8s/secret-redis-tls.yaml
EOF
)"
pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f k8s/secret-flask-tls.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 5. Add Docker Registry Secret to Kubernetes'
printf '%s\n' ''
printf '%s\n' 'A pull secret is needed to pull both the native and confidential container images. Use `tplenv` to supply the registry credentials — it will prompt for any values not yet present in `Values.yaml`:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` — the registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` — your registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` — your registry pull token (see [how to create a token](https://sconedocs.github.io/registry/))'
printf '%s\n' ''
printf '%s\n' 'We create the pull secret in the namespace if it does not yet exist:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
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
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} )
EOF
)"
pe "$(cat <<'EOF'
  # Create the Docker registry pull secret.
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 6. Generate the manifest from the template'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Review `k8s/manifest.yaml`, then apply it:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 7. Verify the native deployment'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Watch all resources come up
EOF
)"
pe "$(cat <<'EOF'
# List the Kubernetes resources in the namespace.
EOF
)"
pe "$(cat <<'EOF'
kubectl get all -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Wait for Redis
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/redis -n ${NAMESPACE}  --watch=true  --timeout=240s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Wait for Flask API
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --watch=true  --timeout=240s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Check logs
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 8. Test the native API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the Flask API pod:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the previous background process if it is still running.
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Capture the name of a ready pod for port-forwarding.
EOF
)"
pe "$(cat <<'EOF'
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
EOF
)"
pe "$(cat <<'EOF'
    | select(.metadata.deletionTimestamp == null)
EOF
)"
pe "$(cat <<'EOF'
    | select(.status.phase=="Running")
EOF
)"
pe "$(cat <<'EOF'
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
EOF
)"
pe "$(cat <<'EOF'
    | .metadata.name' | head -n1)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Start a local port-forward to the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then send requests to `http://localhost:14996`. Note that we are only using `http` (and not yet `https`):'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# List all stored keys
EOF
)"
pe "$(cat <<'EOF'
# Request the list of stored keys from the service.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/keys
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Create a client record
EOF
)"
pe "$(cat <<'EOF'
# Create a test client record through the API.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -X POST http://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Retrieve a client
EOF
)"
pe "$(cat <<'EOF'
# Fetch the stored client record from the API.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/client/abc123
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Get credit score
EOF
)"
pe "$(cat <<'EOF'
# Request the credit score for the test client.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/score/abc123
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Memory dump (debug)
EOF
)"
pe "$(cat <<'EOF'
# Request the debug memory dump from the API.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/memory
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 9. Tear down the native deployment'
printf '%s\n' ''
printf '%s\n' 'Remove the native workloads and secrets before switching to the confidential version:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 2 — Confidential Deployment (SCONE)'
printf '%s\n' ''
printf '%s\n' '### Step 10. Build the confidential (SCONE) images'
printf '%s\n' ''
printf '%s\n' 'When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. By default, `scone-td-build` assumes that this key is stored in the file `identity.pem`. We can generate this file as follows:'
printf '%s\n' ''
printf '%s\n' '- we first check if the file exists, and'
printf '%s\n' '- if it does not exist, we create it with `openssl`'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the signing key needs to be generated.
EOF
)"
pe "$(cat <<'EOF'
if [ ! -f identity.pem ]; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Generating identity.pem ..."
EOF
)"
pe "$(cat <<'EOF'
  # Generate the signing key for confidential binaries.
EOF
)"
pe "$(cat <<'EOF'
  openssl genrsa -3 -out identity.pem 3072
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
  echo "identity.pem already exists."
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Generate the SCONE config from its template, then run `scone-td-build` to produce hardened confidential images for both Redis and Flask and push them to the registry:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent
EOF
)"
pe "$(cat <<'EOF'
# Remove `flask-redis-demo.json` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm flask-redis-demo.json || true
EOF
)"
pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
scone-td-build from -y scone.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 11. Deploy the confidential version'
printf '%s\n' ''
printf '%s\n' 'Apply the production sanitized manifest that references the SCONE confidential images:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 12. Verify the confidential deployment'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Watch all resources come up
EOF
)"
pe "$(cat <<'EOF'
# List the Kubernetes resources in the namespace.
EOF
)"
pe "$(cat <<'EOF'
kubectl get all -n ${NAMESPACE}
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Wait for Redis
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Wait for Flask API
EOF
)"
pe "$(cat <<'EOF'
# Wait for the deployment rollout to complete.
EOF
)"
pe "$(cat <<'EOF'
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=300s
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Check logs
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 13. Test the confidential API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the confidential Flask API pod:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the previous background process if it is still running.
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Capture the name of a ready pod for port-forwarding.
EOF
)"
pe "$(cat <<'EOF'
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
EOF
)"
pe "$(cat <<'EOF'
    | select(.metadata.deletionTimestamp == null)
EOF
)"
pe "$(cat <<'EOF'
    | select(.status.phase=="Running")
EOF
)"
pe "$(cat <<'EOF'
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
EOF
)"
pe "$(cat <<'EOF'
    | .metadata.name' | head -n1)
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Start a local port-forward to the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# List all stored keys
EOF
)"
pe "$(cat <<'EOF'
# Request the list of stored keys from the service.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/keys
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Create a client record
EOF
)"
pe "$(cat <<'EOF'
# Create a test client record through the API.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -X POST http://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Retrieve a client
EOF
)"
pe "$(cat <<'EOF'
# Fetch the stored client record from the API.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/client/abc123
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Get credit score
EOF
)"
pe "$(cat <<'EOF'
# Request the credit score for the test client.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/score/abc123
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Memory dump (debug)
EOF
)"
pe "$(cat <<'EOF'
# Request the debug memory dump from the API.
EOF
)"
pe "$(cat <<'EOF'
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/memory
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Cleanup'
printf '%s\n' ''
printf '%s\n' 'Remove all deployed resources when you are finished:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Stop the port-forward
EOF
)"
pe "$(cat <<'EOF'
# Stop the previous background process if it is still running.
EOF
)"
pe "$(cat <<'EOF'
kill $(cat /tmp/pf-14996.pid) 2> /dev/null || true
EOF
)"
pe "$(cat <<'EOF'
# Remove `/tmp/pf-14996.pid` if it exists.
EOF
)"
pe "$(cat <<'EOF'
rm /tmp/pf-14996.pid
EOF
)"
pe "$(cat <<'EOF'

EOF
)"
pe "$(cat <<'EOF'
# Delete confidential manifest resources
EOF
)"
pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE} --ignore-not-found
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## API Endpoints'
printf '%s\n' ''
printf '%s\n' 'All endpoints are exposed on port `4996` (mapped to `443` in Kubernetes).'
printf '%s\n' ''
printf '%s\n' '| Method | Path | Description |'
printf '%s\n' '|--------|------|-------------|'
printf '%s\n' '| `POST` | `/client/<client_id>` | Create a new client record |'
printf '%s\n' '| `GET` | `/client/<client_id>` | Retrieve a client by ID |'
printf '%s\n' '| `GET` | `/score/<client_id>` | Get the credit score for a client |'
printf '%s\n' '| `GET` | `/keys` | List all stored client records |'
printf '%s\n' '| `GET` | `/memory` | Dump process memory (debug only) |'
printf "%b" "$RESET"

