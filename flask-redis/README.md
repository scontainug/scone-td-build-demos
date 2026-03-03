# flask-redis

A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.

## Project Structure

```
flask-redis/
├── app.py                  # Flask application
├── Dockerfile              # Flask image build
├── requirements.txt        # Python dependencies
├── deploy.sh               # Automated deploy + test script
├── k8s/
│   └── manifest.template.yaml  # Redis + Flask API deployment template
└── README.md
```

---

## Deploy

There are two ways to deploy: run the **automated script** (recommended) or follow the **manual steps** below.

---

### Option A — Automated script

The `deploy.sh` script handles everything end-to-end: TLS cert generation, Docker build and push, Kubernetes secret and manifest generation, deployment, and integration tests via port-forward. It also cleans up all deployed resources when it finishes (or if something goes wrong).

#### Usage

```
Usage: ./deploy.sh --image <IMAGE> [--certs <CERTS_DIR>] [--k8s <K8S_DIR>] [--namespace <NAMESPACE>]

Flags:
  -i, --image        Image name (required), e.g. myregistry/flask-redis-api:latest
  --certs            Path to certs directory (default: <script-dir>/certs)
  --k8s              Path to k8s manifests directory (default: <script-dir>/k8s)
  -n, --namespace    Kubernetes namespace (default: flask-redis)
```

#### Example

```bash
chmod +x deploy.sh
./deploy.sh --image myregistry/flask-redis-api:latest
```

With custom paths:

```bash
./deploy.sh \
  --image myregistry/flask-redis-api:latest \
  --certs ./my-certs \
  --k8s ./k8s \
  --namespace flask-redis
```

The script will pause after generating the secret and manifest YAML files in `--k8s` so you can inspect them before anything is applied to the cluster. After the tests finish, all deployed resources are automatically removed.

---

### Option B — Manual steps

#### Prerequisites

- `kubectl` configured for your cluster
- `docker` with access to a registry your cluster can pull from
- `openssl` and `envsubst` available in your shell

---

#### 1. Generate TLS certificates

```bash
mkdir -p certs

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
```

| File | Used by | Purpose |
|---|---|---|
| `redis-ca.crt` | Both | CA that signed all certs |
| `redis.crt` / `redis.key` | Redis | Redis server cert/key |
| `flask.crt` / `flask.key` | Flask | Flask HTTPS server cert/key |
| `client.crt` / `client.key` | Flask | mTLS client cert for Redis |

---

#### 2. Build and push the Docker image

```bash
docker build -t <your-registry>/flask-redis-api:latest .
docker push <your-registry>/flask-redis-api:latest
```

---

#### 3. Create the namespace

```bash
kubectl create namespace flask-redis
```

---

#### 4. Generate and inspect secret manifests

Generate the secret YAML files locally so you can inspect them before applying:

```bash
kubectl create secret generic redis-tls \
  --namespace flask-redis \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml

kubectl create secret generic flask-tls \
  --namespace flask-redis \
  --from-file=flask.crt=certs/flask.crt \
  --from-file=flask.key=certs/flask.key \
  --from-file=client.crt=certs/client.crt \
  --from-file=client.key=certs/client.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-flask-tls.yaml
```

Review the files in `k8s/`, then apply them:

```bash
kubectl apply -f k8s/secret-redis-tls.yaml
kubectl apply -f k8s/secret-flask-tls.yaml
```

---

#### 5. Generate the manifest from the template

```bash
export IMAGE_NAME=<your-registry>/flask-redis-api:latest
envsubst '$IMAGE_NAME' < k8s/manifest.template.yaml > k8s/manifest.yaml
```

Review `k8s/manifest.yaml`, then apply it:

```bash
kubectl apply -f k8s/manifest.yaml --namespace flask-redis
```

---

#### 6. Verify the deployment

```bash
# Watch all resources come up
kubectl get all -n flask-redis

# Wait for Redis
kubectl rollout status deployment/redis -n flask-redis --timeout=120s

# Wait for Flask API
kubectl rollout status deployment/flask-api -n flask-redis --timeout=120s

# Check logs
kubectl logs -n flask-redis -l app=flask-api --tail=50
kubectl logs -n flask-redis -l app=redis --tail=20
```

---

#### 7. Test the API via port-forward

Open a port-forward to the Flask API pod:

```bash
kubectl port-forward -n flask-redis \
  $(kubectl get pod -n flask-redis -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \
  14996:4996
```

Then in another terminal, send requests against `https://localhost:14996`:

```bash
# List all stored keys
curl -sk https://localhost:14996/keys

# Create a client record
curl -sk -X POST https://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
curl -sk https://localhost:14996/client/abc123

# Get credit score
curl -sk https://localhost:14996/score/abc123

# Memory dump (debug)
curl -sk https://localhost:14996/memory
```

> `-sk` skips TLS verification for the self-signed certificate.

---

#### 8. Cleanup

```bash
kubectl delete -f k8s/manifest.yaml --namespace flask-redis --ignore-not-found
kubectl delete secret redis-tls flask-tls --namespace flask-redis --ignore-not-found
kubectl delete namespace flask-redis --ignore-not-found
rm -f k8s/secret-redis-tls.yaml k8s/secret-flask-tls.yaml k8s/manifest.yaml
```

---

## API Endpoints

All endpoints are served over HTTPS on port `4996` (mapped to `443` in Kubernetes).

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/client/<client_id>` | Create a new client record |
| `GET` | `/client/<client_id>` | Retrieve a client by ID |
| `GET` | `/score/<client_id>` | Get the credit score for a client |
| `GET` | `/keys` | List all stored client records |
| `GET` | `/memory` | Dump process memory (debug only) |
