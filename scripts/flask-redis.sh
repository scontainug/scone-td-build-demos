#!/usr/bin/env bash
set -euo pipefail

LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF
# 🛡️ SCONE Flask-Redis Demo: Secure Client-Server API in Kubernetes

This example walks you through deploying a SCONE-protected Flask API backed by
Redis with mutual TLS in Kubernetes. You'll generate certificates, build images,
deploy natively to verify behavior, then transition to a fully protected SCONE deployment.

______________________________________________________________________

### 1. Prerequisites

- A token for accessing 'scone.cloud' images on registry.scontain.com
- A Kubernetes cluster
- The Kubernetes command line tool ('kubectl')
- Rust 'cargo' is installed ('curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh')
- You installed 'tplenv' ('cargo install tplenv') and 'retry-spinner' ('cargo install retry-spinner')
- 'openssl' is available on your PATH

#### 2. Set up the environment

Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest
way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).

______________________________________________________________________

#### 3. Setting up the Environment Variables

First, we ensure we are in the correct directory. Assumption: we start at directory 'scone-td-build-demos'.

EOF
printf "${RESET}"

pushd flask-redis
unset CONFIRM_ALL_ENVIRONMENT_VARIABLES

printf "${LILAC}"
cat <<EOF

The default values of several environment variables are defined in file 'Values.yaml'.
'tplenv' asks you if all defaults are ok. It then sets the environment variables:

 - '\$IMAGE'                  - name of the container image to build and deploy
 - '\$IMAGE_PULL_SECRET_NAME' - the name of the pull secret (default: 'scontain')
 - '\$NAMESPACE'              - the Kubernetes namespace (default: 'flask-redis')
 - '\$SCONE_VERSION'          - the SCONE version to use
 - '\$CAS_NAMESPACE'          - the CAS namespace (e.g., 'default')
 - '\$CAS_NAME'               - the CAS name (e.g., 'cas')
 - '\$CVM_MODE'               - set to '--cvm' for CVM mode, leave empty for SGX
 - '\$SCONE_ENCLAVE'          - set to '--scone-enclave' for confidential K8s nodes, empty for Kata-Pods

Ensure that we ask the user to confirm or modify all environment variables:

export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"

'tplenv' will now ask the user for all environment variables described in file 'environment-variables.md':

EOF
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🔐 4. Generate TLS Certificates

We generate a CA, a Redis server cert, a Flask server cert, and a client cert
(used by Flask to connect to Redis over mutual TLS):

EOF
printf "${RESET}"

mkdir -p certs

# CA
openssl genrsa -out certs/redis-ca.key 4096 2>/dev/null
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca" 2>/dev/null

# Redis server cert
openssl genrsa -out certs/redis.key 2048 2>/dev/null
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis" 2>/dev/null
openssl x509 -req -in certs/redis.csr \
  -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256 2>/dev/null

# Flask server cert
openssl genrsa -out certs/flask.key 2048 2>/dev/null
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api" 2>/dev/null
openssl x509 -req -in certs/flask.csr \
  -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256 2>/dev/null

# Client cert
openssl genrsa -out certs/client.key 2048 2>/dev/null
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client" 2>/dev/null
openssl x509 -req -in certs/client.csr \
  -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/client.crt -days 365 -sha256 2>/dev/null

printf "${LILAC}"
cat <<EOF

✅ Certificates generated in 'certs/'.

______________________________________________________________________

## 🧱 5. Build the Native Image

This step builds a native version of the image to validate behavior before
enforcing protection with SCONE.

EOF
printf "${RESET}"

docker build -t ${IMAGE} .
docker push ${IMAGE}

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧩 Step 6: Render the Manifests

To render the manifests, we first define the signer key used to sign policies:

EOF
printf "${RESET}"

export SIGNER="$(scone self show-session-signing-key)"

printf "${LILAC}"
cat <<EOF

We then instantiate the manifest templates:

EOF
printf "${RESET}"

tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml  --indent
tplenv --file scone.template.yaml        --create-values-file --output scone.yaml          --indent

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🔑 7. Add Docker Registry Secret to Kubernetes

We check if the pull secret already exists. If not, we ask for credentials:

- '\$REGISTRY'       - the registry name (default: 'registry.scontain.com')
- '\$REGISTRY_USER'  - the login name of the user pulling the container image
- '\$REGISTRY_TOKEN' - the token to pull the image (see https://sconedocs.github.io/registry/)

EOF
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force)
  kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
fi

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🏗️ 8. Create Namespace and TLS Secrets

We create the Kubernetes namespace and populate it with the TLS secrets
generated in step 4:

EOF
printf "${RESET}"

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

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

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧪 9. Deploy the Native App [OPTIONAL]

EOF
printf "${RESET}"

kubectl apply -f k8s/manifest.yaml

retry-spinner -- kubectl rollout status deployment/redis    -n "${NAMESPACE}"
retry-spinner -- kubectl rollout status deployment/flask-api -n "${NAMESPACE}"

kubectl delete -f k8s/manifest.yaml

printf "${LILAC}"
cat <<EOF

✅ Native deployments came up successfully.

______________________________________________________________________

## 🧩 10. Prepare and Apply the SCONE Manifest

EOF
printf "${RESET}"

scone-td-build from -y scone.yaml

printf "${LILAC}"
cat <<EOF

This step:

- Generates a SCONE session
- Attaches it to your manifest
- Produces a new 'manifest.prod.sanitized.yaml' with the necessary information
  to use the created session

______________________________________________________________________

## 🚀 11. Deploy the SCONE-Protected App

EOF
printf "${RESET}"

kubectl apply -f manifest.prod.sanitized.yaml

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🔍 12. Test the Deployment

We port-forward the Flask API and run integration tests to verify the deployment:

EOF
printf "${RESET}"

retry-spinner -- kubectl rollout status deployment/redis    -n "${NAMESPACE}"
retry-spinner -- kubectl rollout status deployment/flask-api -n "${NAMESPACE}"

FLASK_POD=$(kubectl get pod -n "${NAMESPACE}" -l app=flask-api \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n "${NAMESPACE}" "pod/${FLASK_POD}" 14996:4996 &>/dev/null &
PF_PID=$!
sleep 3

BASE_URL="https://localhost:14996"
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local description="$1"
  local expected_pattern="$2"
  local actual_output="$3"
  if echo "$actual_output" | grep -qiE "$expected_pattern"; then
    echo "✅ TEST PASSED: $description"
    (( TESTS_PASSED++ )) || true
  else
    echo "❌ TEST FAILED: $description"
    echo "   Output: $actual_output"
    (( TESTS_FAILED++ )) || true
  fi
}

KEYS_RESPONSE=$(curl -sk -o /dev/null -w "%{http_code}" "$BASE_URL/keys")
run_test "GET /keys returns 200" "^200$" "$KEYS_RESPONSE"

CREATE_RESPONSE=$(curl -sk -X POST "$BASE_URL/client/test001" \
  -F fname=Jane -F lname=Smith -F address="456 Oak Ave" \
  -F city="Testville" -F iban="GB29NWBK60161331926819" \
  -F ssn="987-65-4321" -F email="jane@example.com")
run_test "POST /client/test001 creates a record" "test001|created|ok|success|200" "$CREATE_RESPONSE"

GET_RESPONSE=$(curl -sk "$BASE_URL/client/test001")
run_test "GET /client/test001 returns client data" "Jane|Smith|test001" "$GET_RESPONSE"

SCORE_RESPONSE=$(curl -sk "$BASE_URL/score/test001")
run_test "GET /score/test001 returns a score" "score|[0-9]+" "$SCORE_RESPONSE"

MEMORY_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "$BASE_URL/memory")
run_test "GET /memory endpoint responds" "^(200|403|404|500)$" "$MEMORY_STATUS"

kill "$PF_PID" 2>/dev/null || true

echo ""
echo "========================================"
echo "  Tests passed: $TESTS_PASSED"
echo "  Tests failed: $TESTS_FAILED"
echo "========================================"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
  echo "❌ $TESTS_FAILED test(s) failed"
  popd
  exit 1
fi

printf "${LILAC}"
cat <<EOF

✅ All integration tests passed.

______________________________________________________________________

## 📜 13. View Logs

Check that SCONE-protected containers are running correctly:

EOF
printf "${RESET}"

retry-spinner -- kubectl logs deployment/redis     -n "${NAMESPACE}" --follow
retry-spinner -- kubectl logs deployment/flask-api -n "${NAMESPACE}" --follow

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧹 14. Clean Up

EOF
printf "${RESET}"

kubectl delete -f manifest.prod.sanitized.yaml
kubectl delete namespace "${NAMESPACE}" --ignore-not-found

popd
