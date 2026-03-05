#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

# Local port used for port-forwarding to the Flask API
LOCAL_PORT=14996
PF_PID=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*"; exit 1; }

# ---------------------------------------------------------------------------
# Cleanup — runs on EXIT (success or error)
# ---------------------------------------------------------------------------
NAMESPACE_CREATED=false

cleanup() {
  local exit_code=$?

  echo
  log "Running cleanup..."

  # Stop port-forward if still running
  if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" 2>/dev/null; then
    log "Stopping port-forward (PID $PF_PID)..."
    kill "$PF_PID" 2>/dev/null || true
  fi

  log "Deleting native manifest resources..."
  kubectl delete -f k8s/manifest.yaml --namespace "${NAMESPACE:-flask-redis}" --ignore-not-found || true

  log "Deleting confidential manifest resources..."
  kubectl delete -f manifest.prod.sanitized.yaml--namespace "${NAMESPACE:-flask-redis}" --ignore-not-found || true

  log "Deleting TLS secrets..."
  kubectl delete secret redis-tls flask-tls --namespace "${NAMESPACE:-flask-redis}" --ignore-not-found || true

  if [[ "$NAMESPACE_CREATED" == true ]]; then
    log "Deleting namespace ${NAMESPACE:-flask-redis}..."
    kubectl delete namespace "${NAMESPACE:-flask-redis}" --ignore-not-found || true
  fi

  log "Removing generated k8s YAML files..."
  rm -f k8s/secret-redis-tls.yaml k8s/secret-flask-tls.yaml k8s/manifest.yaml

  if [[ $exit_code -eq 0 ]]; then
    ok "Cleanup complete"
  else
    log "Cleanup complete (script exited with error code $exit_code)"
  fi
}

trap cleanup EXIT

printf "${VIOLET}"
printf '%s\n' '# flask-redis'
printf '%s\n' ''
printf '%s\n' 'A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.'
printf '%s\n' 'This script deploys the **native** version first, runs integration tests,'
printf '%s\n' 'then builds and deploys the **confidential** (SCONE) version and tests it again.'
printf '%s\n' ''
printf '%s\n' '## Project Structure'
printf '%s\n' ''
printf '%s\n' 'flask-redis/'
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
printf '%s\n' '## Deploy'
printf '%s\n' ''
printf '%s\n' 'Run the script end-to-end:'
printf '%s\n' ''
printf '%s\n' '  chmod +x deploy.sh && ./deploy.sh'
printf '%s\n' ''
printf '%s\n' 'The script will:'
printf '%s\n' '  1. Generate TLS certificates'
printf '%s\n' '  2. Collect environment variables via tplenv'
printf '%s\n' '  3. Build and push the native Docker image'
printf '%s\n' '  4. Deploy the native version to Kubernetes and run integration tests'
printf '%s\n' '  5. Tear down the native deployment'
printf '%s\n' '  6. Build the confidential SCONE images via scone-td-build'
printf '%s\n' '  7. Deploy the confidential version to Kubernetes and run integration tests'
printf '%s\n' '  8. Clean up all deployed resources'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Prerequisites'
printf '%s\n' ''
printf '%s\n' '- `kubectl` configured for your cluster'
printf '%s\n' '- `docker` with access to a registry your cluster can pull from'
printf '%s\n' '- `openssl`, `tplenv`, and `envsubst` available in your shell'
printf '%s\n' '- `scone-td-build` binary '
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 1. Generate TLS certificates'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cd flask-redis'
printf '%s\n' 'mkdir -p certs'
printf '%s\n' ''
printf '%s\n' '# CA'
printf '%s\n' 'openssl genrsa -out certs/redis-ca.key 4096'
printf '%s\n' 'openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \'
printf '%s\n' '  -out certs/redis-ca.crt -subj "/CN=redis-ca"'
printf '%s\n' ''
printf '%s\n' '# Redis server cert'
printf '%s\n' 'openssl genrsa -out certs/redis.key 2048'
printf '%s\n' 'openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"'
printf '%s\n' 'openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \'
printf '%s\n' '  -CAcreateserial -out certs/redis.crt -days 365 -sha256'
printf '%s\n' ''
printf '%s\n' '# Flask server cert'
printf '%s\n' 'openssl genrsa -out certs/flask.key 2048'
printf '%s\n' 'openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"'
printf '%s\n' 'openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \'
printf '%s\n' '  -CAcreateserial -out certs/flask.crt -days 365 -sha256'
printf '%s\n' ''
printf '%s\n' '# Client cert (used by Flask to connect to Redis)'
printf '%s\n' 'openssl genrsa -out certs/client.key 2048'
printf '%s\n' 'openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"'
printf '%s\n' 'openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \'
printf '%s\n' '  -CAcreateserial -out certs/client.crt -days 365 -sha256'
printf "${RESET}"

cd flask-redis
mkdir -p certs

# CA
openssl genrsa -out certs/redis-ca.key 4096 2>/dev/null
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca" 2>/dev/null

# Redis server cert
openssl genrsa -out certs/redis.key 2048 2>/dev/null
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis" 2>/dev/null
openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256 2>/dev/null

# Flask server cert
openssl genrsa -out certs/flask.key 2048 2>/dev/null
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api" 2>/dev/null
openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256 2>/dev/null

# Client cert (used by Flask to connect to Redis)
openssl genrsa -out certs/client.key 2048 2>/dev/null
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client" 2>/dev/null
openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/client.crt -days 365 -sha256 2>/dev/null

ok "Certificates generated"

printf "${VIOLET}"
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
printf '%s\n' '#### 2. Collect environment variables and build the Docker image'
printf '%s\n' ''
printf '%s\n' 'Let `tplenv` query all environment variables used by this example:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf '%s\n' ''
printf '%s\n' 'docker build -t ${IMAGE_NAME} .'
printf '%s\n' 'docker push ${IMAGE_NAME}'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

# Export for envsubst usage in later steps
export IMAGE_NAME
export SCRIPT_DIR

# SCONE_TD_BUILD may be set via environment-variables.md; fall back to default if not
SCONE_TD_BUILD="${SCONE_TD_BUILD:-scone-td-build}"

docker build -t "${IMAGE_NAME}" .
docker push "${IMAGE_NAME}"
ok "Image built and pushed: ${IMAGE_NAME}"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 3. Create the namespace'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -'
printf "${RESET}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
NAMESPACE_CREATED=true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 4. Generate and inspect secret manifests'
printf '%s\n' ''
printf '%s\n' 'Generate the secret YAML files locally so you can inspect them before applying:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create secret generic redis-tls \'
printf '%s\n' '  --namespace ${NAMESPACE} \'
printf '%s\n' '  --from-file=redis.crt=certs/redis.crt \'
printf '%s\n' '  --from-file=redis.key=certs/redis.key \'
printf '%s\n' '  --from-file=redis-ca.crt=certs/redis-ca.crt \'
printf '%s\n' '  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml'
printf '%s\n' ''
printf '%s\n' 'kubectl create secret generic flask-tls \'
printf '%s\n' '  --namespace ${NAMESPACE} \'
printf '%s\n' '  --from-file=flask.crt=certs/flask.crt \'
printf '%s\n' '  --from-file=flask.key=certs/flask.key \'
printf '%s\n' '  --from-file=client.crt=certs/client.crt \'
printf '%s\n' '  --from-file=client.key=certs/client.key \'
printf '%s\n' '  --from-file=redis-ca.crt=certs/redis-ca.crt \'
printf '%s\n' '  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml'
printf "${RESET}"

kubectl create secret generic redis-tls \
  --namespace "${NAMESPACE}" \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml

kubectl create secret generic flask-tls \
  --namespace "${NAMESPACE}" \
  --from-file=flask.crt=certs/flask.crt \
  --from-file=flask.key=certs/flask.key \
  --from-file=client.crt=certs/client.crt \
  --from-file=client.key=certs/client.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Review the files in `k8s/`, then apply them:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f k8s/secret-redis-tls.yaml'
printf '%s\n' 'kubectl apply -f k8s/secret-flask-tls.yaml'
printf "${RESET}"

kubectl apply -f k8s/secret-redis-tls.yaml
kubectl apply -f k8s/secret-flask-tls.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 5. Add Docker Registry Secret to Kubernetes'
printf '%s\n' ''
printf '%s\n' 'We assume you need a pull secret to pull both the native and confidential container images.'
printf '%s\n' 'First, we check whether the pull secret is already set. If it is not, we ask the user'
printf '%s\n' 'for the information needed to create it:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.'
printf '%s\n' '- `$REGISTRY_USER` - the login name of the user that pulls the container image.'
printf '%s\n' '- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.'
printf '%s\n' ''
printf '%s\n' 'Note that `tplenv` stores this information in `Values.yaml`.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" -n ${NAMESPACE} >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists in namespace ${NAMESPACE}"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist in namespace ${NAMESPACE} - creating now."'
printf '%s\n' '  # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )'
printf '%s\n' '  kubectl create secret docker-registry -n ${NAMESPACE} "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists in namespace ${NAMESPACE}"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist in namespace ${NAMESPACE} - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force)
  kubectl create secret docker-registry -n ${NAMESPACE} "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 6. Generate the manifest from the template'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml'
printf "${RESET}"

tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Review `k8s/manifest.yaml`, then apply it:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}'
printf "${RESET}"

kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 7. Verify the native deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Watch all resources come up'
printf '%s\n' 'kubectl get all -n ${NAMESPACE}'
printf '%s\n' ''
printf '%s\n' '# Wait for Redis'
printf '%s\n' 'kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=120s'
printf '%s\n' ''
printf '%s\n' '# Wait for Flask API'
printf '%s\n' 'kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=120s'
printf '%s\n' ''
printf '%s\n' '# Check logs'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=redis --tail=20'
printf "${RESET}"

kubectl get all -n ${NAMESPACE}

kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=120s \
  || kubectl wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=120s \
  || fail "Redis pod did not become ready in time"
ok "Redis is running"

kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=120s \
  || kubectl wait --for=condition=ready pod -l app=flask-api -n ${NAMESPACE} --timeout=120s \
  || fail "Flask API pod did not become ready in time"
ok "Flask API is running"

kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 8. Test the native API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the Flask API pod:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl port-forward -n ${NAMESPACE} \'
printf '%s\n' "  \$(kubectl get pod -n \${NAMESPACE} -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \\"
printf '%s\n' '  14996:4996 &'
printf "${RESET}"

FLASK_POD=$(kubectl get pod -n "${NAMESPACE}" -l app=flask-api \
  -o jsonpath='{.items[0].metadata.name}') \
  || fail "Could not find a Flask API pod"

kubectl port-forward -n "${NAMESPACE}" "pod/${FLASK_POD}" "${LOCAL_PORT}:4996" &>/dev/null &
PF_PID=$!

log "Waiting for port-forward to be established..."
for i in $(seq 1 15); do
  if curl -sk --max-time 1 "https://localhost:${LOCAL_PORT}/keys" -o /dev/null 2>/dev/null; then
    break
  fi
  if ! kill -0 "$PF_PID" 2>/dev/null; then
    fail "Port-forward process died unexpectedly"
  fi
  sleep 1
done

curl -sk --max-time 2 "https://localhost:${LOCAL_PORT}/keys" -o /dev/null \
  || fail "Port-forward established but Flask API is not responding on localhost:${LOCAL_PORT}"

ok "Port-forward active on localhost:${LOCAL_PORT} (PID ${PF_PID})"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# List all stored keys'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys'
printf '%s\n' ''
printf '%s\n' '# Create a client record'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk -X POST https://localhost:14996/client/abc123 \'
printf '%s\n' '  -F fname=John \'
printf '%s\n' '  -F lname=Doe \'
printf '%s\n' '  -F address="123 Main St" \'
printf '%s\n' '  -F city="Springfield" \'
printf '%s\n' '  -F iban="DE89370400440532013000" \'
printf '%s\n' '  -F ssn="123-45-6789" \'
printf '%s\n' '  -F email="john@example.com"'
printf '%s\n' ''
printf '%s\n' '# Retrieve a client'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk https://localhost:14996/client/abc123'
printf '%s\n' ''
printf '%s\n' '# Get credit score'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk https://localhost:14996/score/abc123'
printf '%s\n' ''
printf '%s\n' '# Memory dump (debug)'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory'
printf "${RESET}"

BASE_URL="https://localhost:${LOCAL_PORT}"
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local description="$1"
  local expected_pattern="$2"
  local actual_output="$3"

  if echo "$actual_output" | grep -qiE "$expected_pattern"; then
    ok "TEST PASSED: $description"
    (( TESTS_PASSED++ )) || true
  else
    echo "[$(date '+%H:%M:%S')] ❌ TEST FAILED: $description"
    echo "   Output: $actual_output"
    (( TESTS_FAILED++ )) || true
  fi
}

log "Running native integration tests via localhost:${LOCAL_PORT}..."

# Test 1: GET /keys
log "Test 1: GET /keys"
KEYS_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -o /dev/null -w "%{http_code}" "$BASE_URL/keys")
run_test "GET /keys returns 200" "^200$" "$KEYS_RESPONSE"

# Test 2: POST /client/abc123
log "Test 2: POST /client/abc123"
CREATE_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -X POST "$BASE_URL/client/abc123" \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com")
run_test "POST /client/abc123 creates a record" "abc123|created|ok|success|200" "$CREATE_RESPONSE"

# Test 3: GET /client/abc123
log "Test 3: GET /client/abc123"
GET_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk "$BASE_URL/client/abc123")
run_test "GET /client/abc123 returns client data" "John|Doe|abc123" "$GET_RESPONSE"

# Test 4: GET /score/abc123
log "Test 4: GET /score/abc123"
SCORE_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk "$BASE_URL/score/abc123")
run_test "GET /score/abc123 returns a score" "score|[0-9]+" "$SCORE_RESPONSE"

# Test 5: GET /memory
log "Test 5: GET /memory"
MEMORY_STATUS=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -o /dev/null -w "%{http_code}" "$BASE_URL/memory")
run_test "GET /memory endpoint responds" "^(200|403|404|500)$" "$MEMORY_STATUS"

echo
echo "========================================"
echo "  Native tests passed: $TESTS_PASSED"
echo "  Native tests failed: $TESTS_FAILED"
echo "========================================"
[[ "$TESTS_FAILED" -eq 0 ]] || fail "$TESTS_FAILED native test(s) failed — check logs above"
ok "All native tests passed"

# Stop port-forward before tearing down the native deployment
if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" 2>/dev/null; then
  log "Stopping native port-forward (PID $PF_PID)..."
  kill "$PF_PID" 2>/dev/null || true
  PF_PID=""
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> `-sk` skips TLS verification for the self-signed certificate.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 9. Tear down the native deployment'
printf '%s\n' ''
printf '%s\n' 'Remove the native workloads and secrets before switching to the confidential version:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found'
printf "${RESET}"

kubectl delete -f k8s/manifest.yaml --namespace "${NAMESPACE}" --ignore-not-found || true
kubectl delete secret redis-tls flask-tls --namespace "${NAMESPACE}" --ignore-not-found || true
ok "Native deployment removed"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 10. Build the confidential (SCONE) images'
printf '%s\n' ''
printf '%s\n' 'Generate the SCONE config from its template, then run `scone-td-build` to produce'
printf '%s\n' 'hardened confidential images for both Redis and Flask, and push them to the registry:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'envsubst '\''$IMAGE_NAME $SCRIPT_DIR'\'' < scone.template.yaml > scone.yaml'
printf '%s\n' 'scone-td-build from -y scone.yaml'
printf '%s\n' 'docker push "${IMAGE_NAME}-redis-scone"'
printf '%s\n' 'docker push "${IMAGE_NAME}-scone"'
printf "${RESET}"

log "Generating scone.yaml from template..."
tplenv --file scone.template.yaml --create-values-file --output scone.yaml
ok "SCONE config generated at scone.yaml"

log "Running scone-td-build to produce confidential images..."
"${SCONE_TD_BUILD}" from -y scone.yaml || fail "scone-td-build failed"
ok "Confidential images built"

log "Pushing confidential Redis image: ${IMAGE_NAME}-redis-scone"
docker push "${IMAGE_NAME}-redis-scone" || fail "Failed to push ${IMAGE_NAME}-redis-scone"
ok "Pushed ${IMAGE_NAME}-redis-scone"

log "Pushing confidential Flask image: ${IMAGE_NAME}-scone"
docker push "${IMAGE_NAME}-scone" || fail "Failed to push ${IMAGE_NAME}-scone"
ok "Pushed ${IMAGE_NAME}-scone"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 11. Deploy the confidential version'
printf '%s\n' ''
printf '%s\n' 'Apply the production sanitized manifest that references the SCONE confidential images:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}'
printf "${RESET}"

kubectl apply -f manifest.prod.sanitized.yaml --namespace "${NAMESPACE}" || fail "kubectl apply of confidential manifest failed"
ok "Confidential manifest applied"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 12. Verify the confidential deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Watch all resources come up'
printf '%s\n' 'kubectl get all -n ${NAMESPACE}'
printf '%s\n' ''
printf '%s\n' '# Wait for Redis'
printf '%s\n' 'kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=300s'
printf '%s\n' ''
printf '%s\n' '# Wait for Flask API'
printf '%s\n' 'kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=300s'
printf '%s\n' ''
printf '%s\n' '# Check logs'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=redis --tail=20'
printf "${RESET}"

kubectl get all -n "${NAMESPACE}"

log "Waiting for confidential Redis to be ready..."
kubectl rollout status deployment/redis -n "${NAMESPACE}" --timeout=300s \
  || kubectl wait --for=condition=ready pod -l app=redis -n "${NAMESPACE}" --timeout=300s \
  || fail "Confidential Redis pod did not become ready in time"
ok "Confidential Redis is running"

log "Waiting for confidential Flask API to be ready..."
kubectl rollout status deployment/flask-api -n "${NAMESPACE}" --timeout=300s \
  || kubectl wait --for=condition=ready pod -l app=flask-api -n "${NAMESPACE}" --timeout=300s \
  || fail "Confidential Flask API pod did not become ready in time"
ok "Confidential Flask API is running"

kubectl logs -n "${NAMESPACE}" -l app=flask-api --tail=50
kubectl logs -n "${NAMESPACE}" -l app=redis --tail=20

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 13. Test the confidential API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the confidential Flask API pod:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl port-forward -n ${NAMESPACE} \'
printf '%s\n' "  \$(kubectl get pod -n \${NAMESPACE} -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \\"
printf '%s\n' '  14996:4996 &'
printf "${RESET}"

FLASK_POD=$(kubectl get pod -n "${NAMESPACE}" -l app=flask-api \
  -o jsonpath='{.items[0].metadata.name}') \
  || fail "Could not find a confidential Flask API pod"

kubectl port-forward -n "${NAMESPACE}" "pod/${FLASK_POD}" "${LOCAL_PORT}:4996" &>/dev/null &
PF_PID=$!

log "Waiting for confidential port-forward to be established..."
for i in $(seq 1 15); do
  if curl -sk --max-time 1 "https://localhost:${LOCAL_PORT}/keys" -o /dev/null 2>/dev/null; then
    break
  fi
  if ! kill -0 "$PF_PID" 2>/dev/null; then
    fail "Port-forward process died unexpectedly"
  fi
  sleep 1
done

curl -sk --max-time 2 "https://localhost:${LOCAL_PORT}/keys" -o /dev/null \
  || fail "Port-forward established but confidential Flask API is not responding on localhost:${LOCAL_PORT}"

ok "Confidential port-forward active on localhost:${LOCAL_PORT} (PID ${PF_PID})"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# List all stored keys'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys'
printf '%s\n' ''
printf '%s\n' '# Create a client record'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk -X POST https://localhost:14996/client/abc123 \'
printf '%s\n' '  -F fname=John \'
printf '%s\n' '  -F lname=Doe \'
printf '%s\n' '  -F address="123 Main St" \'
printf '%s\n' '  -F city="Springfield" \'
printf '%s\n' '  -F iban="DE89370400440532013000" \'
printf '%s\n' '  -F ssn="123-45-6789" \'
printf '%s\n' '  -F email="john@example.com"'
printf '%s\n' ''
printf '%s\n' '# Retrieve a client'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk https://localhost:14996/client/abc123'
printf '%s\n' ''
printf '%s\n' '# Get credit score'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10  -sk https://localhost:14996/score/abc123'
printf '%s\n' ''
printf '%s\n' '# Memory dump (debug)'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory'
printf "${RESET}"

log "Running confidential integration tests via localhost:${LOCAL_PORT}..."
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: GET /keys
log "Test 1: GET /keys"
KEYS_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -o /dev/null -w "%{http_code}" "$BASE_URL/keys")
run_test "GET /keys returns 200" "^200$" "$KEYS_RESPONSE"

# Test 2: POST /client/abc123
log "Test 2: POST /client/abc123"
CREATE_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -X POST "$BASE_URL/client/abc123" \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com")
run_test "POST /client/abc123 creates a record" "abc123|created|ok|success|200" "$CREATE_RESPONSE"

# Test 3: GET /client/abc123
log "Test 3: GET /client/abc123"
GET_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk "$BASE_URL/client/abc123")
run_test "GET /client/abc123 returns client data" "John|Doe|abc123" "$GET_RESPONSE"

# Test 4: GET /score/abc123
log "Test 4: GET /score/abc123"
SCORE_RESPONSE=$(curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk "$BASE_URL/score/abc123")
run_test "GET /score/abc123 returns a score" "score|[0-9]+" "$SCORE_RESPONSE"

# Test 5: GET /memory
log "Test 5: GET /memory"
MEMORY_STATUS=$(curl --retry 5 --retry-all-errors --retry-delay 5 --connect-timeout 10 --max-time 10 -sk -w "%{http_code}" "$BASE_URL/memory")
run_test "GET /memory endpoint responds" "^(200|403|404|500)$" "$MEMORY_STATUS"

echo
echo "========================================"
echo "  Confidential tests passed: $TESTS_PASSED"
echo "  Confidential tests failed: $TESTS_FAILED"
echo "========================================"
[[ "$TESTS_FAILED" -eq 0 ]] || fail "$TESTS_FAILED confidential test(s) failed — check logs above"
ok "All confidential tests passed — deployment verified"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> `-sk` skips TLS verification for the self-signed certificate.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## API Endpoints'
printf '%s\n' ''
printf '%s\n' 'All endpoints are served over HTTPS on port `4996` (mapped to `443` in Kubernetes).'
printf '%s\n' ''
printf '%s\n' '| Method | Path | Description |'
printf '%s\n' '|--------|------|-------------|'
printf '%s\n' '| `POST` | `/client/<client_id>` | Create a new client record |'
printf '%s\n' '| `GET` | `/client/<client_id>` | Retrieve a client by ID |'
printf '%s\n' '| `GET` | `/score/<client_id>` | Get the credit score for a client |'
printf '%s\n' '| `GET` | `/keys` | List all stored client records |'
printf '%s\n' '| `GET` | `/memory` | Dump process memory (debug only) |'
printf "${RESET}"
