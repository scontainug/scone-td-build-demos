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
printf '%s\n' '# flask-redis'
printf '%s\n' ''
printf '%s\n' 'A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.'
printf '%s\n' ''
printf '%s\n' '## Project Structure'
printf '%s\n' ''
printf '%s\n' 'flask-redis/'
printf '%s\n' '├── app.py                  # Flask application'
printf '%s\n' '├── Dockerfile              # Flask image build'
printf '%s\n' '├── requirements.txt        # Python dependencies'
printf '%s\n' '├── deploy.sh               # Automated deploy + test script'
printf '%s\n' '├── k8s/'
printf '%s\n' '│   └── manifest.template.yaml  # Redis + Flask API deployment template'
printf '%s\n' '└── README.md'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Deploy'
printf '%s\n' ''
printf '%s\n' 'There are two ways to deploy: run the **automated script** (recommended) or follow the **manual steps** below.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Option A — Automated script'
printf '%s\n' ''
printf '%s\n' 'The `deploy.sh` script handles everything end-to-end: TLS cert generation, Docker build and push, Kubernetes secret and manifest generation, deployment, and integration tests via port-forward. It also cleans up all deployed resources when it finishes (or if something goes wrong).'
printf '%s\n' ''
printf '%s\n' '#### Usage'
printf '%s\n' ''
printf '%s\n' 'Usage: ./deploy.sh --image <IMAGE> [--certs <CERTS_DIR>] [--k8s <K8S_DIR>] [--namespace <NAMESPACE>]'
printf '%s\n' ''
printf '%s\n' 'Flags:'
printf '%s\n' '  -i, --image        Image name (required), e.g. myregistry/flask-redis-api:latest'
printf '%s\n' '  --certs            Path to certs directory (default: <script-dir>/certs)'
printf '%s\n' '  --k8s              Path to k8s manifests directory (default: <script-dir>/k8s)'
printf '%s\n' '  -n, --namespace    Kubernetes namespace (default: flask-redis)'
printf '%s\n' ''
printf '%s\n' '#### Example'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
chmod +x deploy.sh
EOF
)"
pe "$(cat <<'EOF'
./deploy.sh --image myregistry/flask-redis-api:latest
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'With custom paths:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
./deploy.sh \
  --image myregistry/flask-redis-api:latest \
  --certs ./my-certs \
  --k8s ./k8s \
  --namespace flask-redis
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The script will pause after generating the secret and manifest YAML files in `--k8s` so you can inspect them before anything is applied to the cluster. After the tests finish, all deployed resources are automatically removed.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '### Option B — Manual steps'
printf '%s\n' ''
printf '%s\n' '#### Prerequisites'
printf '%s\n' ''
printf '%s\n' '- `kubectl` configured for your cluster'
printf '%s\n' '- `docker` with access to a registry your cluster can pull from'
printf '%s\n' '- `openssl` and `envsubst` available in your shell'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 1. Generate TLS certificates'
printf '%s\n' ''
printf "%b" "$RESET"

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
openssl genrsa -out certs/redis-ca.key 4096
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
openssl genrsa -out certs/redis.key 2048
EOF
)"
pe "$(cat <<'EOF'
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"
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
openssl genrsa -out certs/flask.key 2048
EOF
)"
pe "$(cat <<'EOF'
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"
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
openssl genrsa -out certs/client.key 2048
EOF
)"
pe "$(cat <<'EOF'
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"
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
printf '%s\n' '#### 2. Build and push the Docker image'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
docker build -t <your-registry>/flask-redis-api:latest .
EOF
)"
pe "$(cat <<'EOF'
docker push <your-registry>/flask-redis-api:latest
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 3. Create the namespace'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl create namespace flask-redis
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 4. Generate and inspect secret manifests'
printf '%s\n' ''
printf '%s\n' 'Generate the secret YAML files locally so you can inspect them before applying:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl create secret generic redis-tls \
  --namespace flask-redis \
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
kubectl create secret generic flask-tls \
  --namespace flask-redis \
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
kubectl apply -f k8s/secret-redis-tls.yaml
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
printf '%s\n' '#### 5. Generate the manifest from the template'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
export IMAGE_NAME=<your-registry>/flask-redis-api:latest
EOF
)"
pe "$(cat <<'EOF'
envsubst '$IMAGE_NAME' < k8s/manifest.template.yaml > k8s/manifest.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Review `k8s/manifest.yaml`, then apply it:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl apply -f k8s/manifest.yaml --namespace flask-redis
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 6. Verify the deployment'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Watch all resources come up
EOF
)"
pe "$(cat <<'EOF'
kubectl get all -n flask-redis
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
kubectl rollout status deployment/redis -n flask-redis --timeout=120s
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
kubectl rollout status deployment/flask-api -n flask-redis --timeout=120s
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
kubectl logs -n flask-redis -l app=flask-api --tail=50
EOF
)"
pe "$(cat <<'EOF'
kubectl logs -n flask-redis -l app=redis --tail=20
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 7. Test the API via port-forward'
printf '%s\n' ''
printf '%s\n' 'Open a port-forward to the Flask API pod:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl port-forward -n flask-redis \
  $(kubectl get pod -n flask-redis -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \
  14996:4996
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Then in another terminal, send requests against `https://localhost:14996`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# List all stored keys
EOF
)"
pe "$(cat <<'EOF'
curl -sk https://localhost:14996/keys
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
curl -sk -X POST https://localhost:14996/client/abc123 \
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
curl -sk https://localhost:14996/client/abc123
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
curl -sk https://localhost:14996/score/abc123
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
curl -sk https://localhost:14996/memory
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '> `-sk` skips TLS verification for the self-signed certificate.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '#### 8. Cleanup'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
kubectl delete -f k8s/manifest.yaml --namespace flask-redis --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
kubectl delete secret redis-tls flask-tls --namespace flask-redis --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
kubectl delete namespace flask-redis --ignore-not-found
EOF
)"
pe "$(cat <<'EOF'
rm -f k8s/secret-redis-tls.yaml k8s/secret-flask-tls.yaml k8s/manifest.yaml
EOF
)"

printf "%b" "$LILAC"
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
printf "%b" "$RESET"

