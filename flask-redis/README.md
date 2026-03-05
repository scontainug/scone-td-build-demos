# flask-redis

A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.
This guide walks through deploying the **native** version first, running integration tests,
then building and deploying the **confidential** (SCONE) version and testing it again.

## Project Structure

```
flask-redis/
├── app.py                       # Flask application
├── Dockerfile                   # Flask image build
├── requirements.txt             # Python dependencies
├── scone.template.yaml          # SCONE confidential build template
├── environment-variables.md     # tplenv variable definitions
├── registry.credentials.md      # tplenv registry credential definitions
├── k8s/
│   └── manifest.template.yaml   # Redis + Flask API deployment template
└── README.md
```

---

## Prerequisites

- `kubectl` configured for your cluster
- `docker` with access to a registry your cluster can pull from
- `openssl`, `tplenv`, and `envsubst` available in your shell
- `scone-td-build` binary

---

## Part 1 — Native Deployment

### Step 1. Generate TLS certificates

```bash
cd flask-redis
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

### Step 2. Collect environment variables and build the Docker image

Let `tplenv` query all environment variables used by this example:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval --force --output /dev/null)
```

Then build and push the native Docker image:

```bash
docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}
```

---

### Step 3. Create the namespace

We try to ensure that the namespace exists. This might fail when running in a container in the right namespace. Hence, we ignore for now.

```bash
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || echo "Patching of namespace ${NAMESPACE}  failed -- ignoring this"
```

---

### Step 4. Generate and inspect secret manifests

Generate the secret YAML files locally so you can inspect them before applying:

```bash
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
```

Review the files in `k8s/`, then apply them:

```bash
kubectl apply -f k8s/secret-redis-tls.yaml
kubectl apply -f k8s/secret-flask-tls.yaml
```

---

### Step 5. Add Docker Registry Secret to Kubernetes

A pull secret is needed to pull both the native and confidential container images. Use `tplenv` to supply the registry credentials — it will prompt for any values not yet present in `Values.yaml`:

- `$REGISTRY` — the registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` — your registry login name
- `$REGISTRY_TOKEN` — your registry pull token (see [how to create a token](https://sconedocs.github.io/registry/))

```bash
eval $(tplenv --file registry.credentials.md --create-values-file --eval --force)
```

Then create the pull secret in the namespace:

```bash
kubectl create secret docker-registry -n ${NAMESPACE} "${IMAGE_PULL_SECRET_NAME}" \
  --docker-server=$REGISTRY \
  --docker-username=$REGISTRY_USER \
  --docker-password=$REGISTRY_TOKEN
```

If the secret already exists from a previous run, you can skip this step or append `--dry-run=client` to verify the values without recreating it.

---

### Step 6. Generate the manifest from the template

```bash
tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml
```

Review `k8s/manifest.yaml`, then apply it:

```bash
kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}
```

---

### Step 7. Verify the native deployment

```bash
# Watch all resources come up
kubectl get all -n ${NAMESPACE}

# Wait for Redis
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=120s

# Wait for Flask API
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=120s

# Check logs
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
```

---

### Step 8. Test the native API via port-forward

Open a port-forward to the Flask API pod:

```bash
kubectl port-forward -n ${NAMESPACE} \
  $(kubectl get pod -n ${NAMESPACE} -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \
  14996:4996 &
```

Then send requests against `https://localhost:14996`:

```bash
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
```

> `-sk` skips TLS verification for the self-signed certificate.

---

### Step 9. Tear down the native deployment

Remove the native workloads and secrets before switching to the confidential version:

```bash
kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found
```

---

## Part 2 — Confidential Deployment (SCONE)

### Step 10. Build the confidential (SCONE) images

Generate the SCONE config from its template, then run `scone-td-build` to produce hardened confidential images for both Redis and Flask, and push them to the registry:

```bash
tplenv --file scone.template.yaml --create-values-file --output scone.yaml
scone-td-build from -y scone.yaml
docker push "${IMAGE_NAME}-redis-scone"
docker push "${IMAGE_NAME}-scone"
```

---

### Step 11. Deploy the confidential version

Apply the production sanitized manifest that references the SCONE confidential images:

```bash
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
```

---

### Step 12. Verify the confidential deployment

```bash
# Watch all resources come up
kubectl get all -n ${NAMESPACE}

# Wait for Redis
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=300s

# Wait for Flask API
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=300s

# Check logs
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
```

---

### Step 13. Test the confidential API via port-forward

Open a port-forward to the confidential Flask API pod:

```bash
kubectl port-forward -n ${NAMESPACE} \
  $(kubectl get pod -n ${NAMESPACE} -l app=flask-api -o jsonpath='{.items[0].metadata.name}') \
  14996:4996 &
```

Then send requests against `https://localhost:14996`:

```bash
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
```

> `-sk` skips TLS verification for the self-signed certificate.

---

## Cleanup

Remove all deployed resources when finished:

```bash
# Stop the port-forward
kill %1

# Delete confidential manifest resources
kubectl delete -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE} --ignore-not-found
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
