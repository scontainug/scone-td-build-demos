#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# flask-redis'
printf '%s\n' ''
printf '%s\n' 'A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.'
printf '%s\n' 'This guide walks through deploying the **native** version first, running integration tests, then building and deploying the **confidential** (SCONE) version and testing it again.'
printf '%s\n' ''
printf '%s\n' '[![Flask Redis Example](../docs/flask-redis.gif)](../docs/flask-redis.mp4)'
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cd flask-redis'
printf '%s\n' 'mkdir -p certs'
printf '%s\n' '# cleanup'
printf '%s\n' 'rm -f flask-redis/flask-redis-demo.json || true'
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
# cleanup
rm -f flask-redis/flask-redis-demo.json || true

# CA
openssl genrsa -out certs/redis-ca.key 4096
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca"

# Redis server cert
openssl genrsa -out certs/redis.key 2048
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"
openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256

# Flask server cert
openssl genrsa -out certs/flask.key 2048
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"
openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256

# Client cert (used by Flask to connect to Redis)
openssl genrsa -out certs/client.key 2048
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"
openssl x509 -req -in certs/client.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/client.crt -days 365 -sha256

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
printf '%s\n' '### Step 2. Collect environment variables and build the Docker image'
printf '%s\n' ''
printf '%s\n' 'Let `tplenv` query all environment variables used by this example:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then build and push the native Docker image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'docker build -t ${IMAGE_NAME} .'
printf '%s\n' 'docker push ${IMAGE_NAME}'
printf "${RESET}"

docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 3. Create the namespace'
printf '%s\n' ''
printf '%s\n' 'We try to ensure the namespace exists. This may fail when running in a container that is already in the target namespace, so we ignore that failure.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || echo "Patching of namespace ${NAMESPACE} failed -- ignoring this"'
printf "${RESET}"

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || echo "Patching of namespace ${NAMESPACE} failed -- ignoring this"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 4. Generate and inspect secret manifests'
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
  --namespace ${NAMESPACE} \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml

kubectl create secret generic flask-tls \
  --namespace ${NAMESPACE} \
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
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})'
printf '%s\n' '  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server="$REGISTRY" --docker-username="$REGISTRY_USER" --docker-password="$REGISTRY_TOKEN"'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES})
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" --docker-server="$REGISTRY" --docker-username="$REGISTRY_USER" --docker-password="$REGISTRY_TOKEN"
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 6. Generate the manifest from the template'
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
printf '%s\n' '### Step 7. Verify the native deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Watch all resources come up'
printf '%s\n' 'kubectl get all -n ${NAMESPACE}'
printf '%s\n' ''
printf '%s\n' '# Wait for Redis'
printf '%s\n' 'kubectl rollout status deployment/redis -n ${NAMESPACE}  --watch=true  --timeout=240s'
printf '%s\n' ''
printf '%s\n' '# Wait for Flask API'
printf '%s\n' 'kubectl rollout status deployment/flask-api -n ${NAMESPACE} --watch=true  --timeout=240s'
printf '%s\n' ''
printf '%s\n' '# Check logs'
printf '%s\n' 'echo "Log of flask-api"'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50'
printf '%s\n' 'echo "Log of flask-api"'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=redis --tail=20'
printf "${RESET}"

# Watch all resources come up
kubectl get all -n ${NAMESPACE}

# Wait for Redis
kubectl rollout status deployment/redis -n ${NAMESPACE}  --watch=true  --timeout=240s

# Wait for Flask API
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --watch=true  --timeout=240s

# Check logs
echo "Log of flask-api"
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
echo "Log of flask-api"
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 8. Test the native API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the Flask API pod:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true'
printf '%s\n' 'POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \'
printf '%s\n' ' | jq -r '\''.items[]'
printf '%s\n' '    | select(.metadata.deletionTimestamp == null)'
printf '%s\n' '    | select(.status.phase=="Running")'
printf '%s\n' '    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))'
printf '%s\n' '    | .metadata.name'\'' | head -n1)'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid'
printf "${RESET}"

kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
    | select(.metadata.deletionTimestamp == null)
    | select(.status.phase=="Running")
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
    | .metadata.name' | head -n1)


kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# List all stored keys'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys'
printf '%s\n' ''
printf '%s\n' '# Create a client record'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -X POST https://localhost:14996/client/abc123 \'
printf '%s\n' '  -F fname=John \'
printf '%s\n' '  -F lname=Doe \'
printf '%s\n' '  -F address="123 Main St" \'
printf '%s\n' '  -F city="Springfield" \'
printf '%s\n' '  -F iban="DE89370400440532013000" \'
printf '%s\n' '  -F ssn="123-45-6789" \'
printf '%s\n' '  -F email="john@example.com"'
printf '%s\n' ''
printf '%s\n' '# Retrieve a client'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/client/abc123'
printf '%s\n' ''
printf '%s\n' '# Get credit score'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/score/abc123'
printf '%s\n' ''
printf '%s\n' '# Memory dump (debug)'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory'
printf "${RESET}"

# List all stored keys
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys

# Create a client record
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -X POST https://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/client/abc123

# Get credit score
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/score/abc123

# Memory dump (debug)
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> `-sk` skips TLS verification for the self-signed certificate.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 9. Tear down the native deployment'
printf '%s\n' ''
printf '%s\n' 'Remove the native workloads and secrets before switching to the confidential version:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=flask-api --timeout=300s'
printf '%s\n' 'kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=redis --timeout=300s'
printf '%s\n' 'kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found'
printf "${RESET}"

kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found
kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=flask-api --timeout=300s
kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=redis --timeout=300s
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Part 2 — Confidential Deployment (SCONE)'
printf '%s\n' ''
printf '%s\n' '### Step 10. Build the confidential (SCONE) images'
printf '%s\n' ''
printf '%s\n' 'When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. `scone-td-build` assumes, by default, that this key is stored in file `identity.pem`. We can generate this file as follows:'
printf '%s\n' ''
printf '%s\n' '- we first check if the file exists, and'
printf '%s\n' '- if it does not exist, we create it with `openssl`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [ ! -f identity.pem ]; then'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  openssl genrsa -3 -out identity.pem 3072'
printf '%s\n' 'else'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

if [ ! -f identity.pem ]; then
  echo "Generating identity.pem ..."
  openssl genrsa -3 -out identity.pem 3072
else
  echo "identity.pem already exists."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Generate the SCONE config from its template, then run `scone-td-build` to produce hardened confidential images for both Redis and Flask and push them to the registry:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file scone.template.yaml --create-values-file --output scone.yaml'
printf '%s\n' 'rm flask-redis-demo.json || true'
printf '%s\n' 'scone-td-build from -y scone.yaml'
printf "${RESET}"

tplenv --file scone.template.yaml --create-values-file --output scone.yaml
rm flask-redis-demo.json || true
scone-td-build from -y scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Push the confidential images so the cluster can pull them:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'grep -oP '\''image: \K\S+'\'' manifest.prod.sanitized.yaml | sort -u | while read -r img; do'
printf '%s\n' '  docker push "${img}"'
printf '%s\n' 'done'
printf "${RESET}"

grep -oP 'image: \K\S+' manifest.prod.sanitized.yaml | sort -u | while read -r img; do
  docker push "${img}"
done

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 11. Deploy the confidential version'
printf '%s\n' ''
printf '%s\n' 'Apply the production sanitized manifest that references the SCONE confidential images:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}'
printf "${RESET}"

kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 12. Verify the confidential deployment'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Watch all resources come up'
printf '%s\n' 'kubectl get all -n ${NAMESPACE}'
printf '%s\n' ''
printf '%s\n' '# Wait for Redis'
printf '%s\n' 'kubectl wait --for=condition=Ready pod --namespace ${NAMESPACE} -l app=flask-api --timeout=300s'
printf '%s\n' ''
printf '%s\n' '# Wait for Flask API'
printf '%s\n' 'kubectl wait --for=condition=Ready pod --namespace ${NAMESPACE} -l app=redis --timeout=300s'
printf '%s\n' ''
printf '%s\n' '# Check logs'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50'
printf '%s\n' 'kubectl logs -n ${NAMESPACE} -l app=redis --tail=20'
printf "${RESET}"

# Watch all resources come up
kubectl get all -n ${NAMESPACE}

# Wait for Redis
kubectl wait --for=condition=Ready pod --namespace ${NAMESPACE} -l app=flask-api --timeout=300s

# Wait for Flask API
kubectl wait --for=condition=Ready pod --namespace ${NAMESPACE} -l app=redis --timeout=300s

# Check logs
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Step 13. Test the confidential API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the confidential Flask API pod:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true'
printf '%s\n' 'POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \'
printf '%s\n' ' | jq -r '\''.items[]'
printf '%s\n' '    | select(.metadata.deletionTimestamp == null)'
printf '%s\n' '    | select(.status.phase=="Running")'
printf '%s\n' '    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))'
printf '%s\n' '    | .metadata.name'\'' | head -n1)'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid'
printf "${RESET}"

kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
    | select(.metadata.deletionTimestamp == null)
    | select(.status.phase=="Running")
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
    | .metadata.name' | head -n1)

kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Then send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# List all stored keys'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys'
printf '%s\n' ''
printf '%s\n' '# Create a client record'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -X POST https://localhost:14996/client/abc123 \'
printf '%s\n' '  -F fname=John \'
printf '%s\n' '  -F lname=Doe \'
printf '%s\n' '  -F address="123 Main St" \'
printf '%s\n' '  -F city="Springfield" \'
printf '%s\n' '  -F iban="DE89370400440532013000" \'
printf '%s\n' '  -F ssn="123-45-6789" \'
printf '%s\n' '  -F email="john@example.com"'
printf '%s\n' ''
printf '%s\n' '# Retrieve a client'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/client/abc123'
printf '%s\n' ''
printf '%s\n' '# Get credit score'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/score/abc123'
printf '%s\n' ''
printf '%s\n' '# Memory dump (debug)'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory'
printf "${RESET}"

# List all stored keys
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/keys

# Create a client record
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk -X POST https://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/client/abc123

# Get credit score
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/score/abc123

# Memory dump (debug)
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -sk https://localhost:14996/memory

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> `-sk` skips TLS verification for the self-signed certificate.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Cleanup'
printf '%s\n' ''
printf '%s\n' 'Remove all deployed resources when you are finished:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Stop the port-forward'
printf '%s\n' 'kill $(cat /tmp/pf-14996.pid) 2> /dev/null || true'
printf '%s\n' 'rm /tmp/pf-14996.pid'
printf '%s\n' ''
printf '%s\n' '# Delete confidential manifest resources'
printf '%s\n' 'kubectl delete -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE} --ignore-not-found'
printf '%s\n' 'kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=flask-api --timeout=300s'
printf '%s\n' 'kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=redis --timeout=300s'
printf "${RESET}"

# Stop the port-forward
kill $(cat /tmp/pf-14996.pid) 2> /dev/null || true
rm /tmp/pf-14996.pid

# Delete confidential manifest resources
kubectl delete -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE} --ignore-not-found
kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=flask-api --timeout=300s
kubectl wait --for=delete pod --namespace ${NAMESPACE} -l app=redis --timeout=300s

printf "${VIOLET}"
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

