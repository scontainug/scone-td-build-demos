# flask-redis

A Flask REST API backed by a TLS-secured Redis instance, packaged for Kubernetes.
This guide walks through deploying the **native** version first, running integration tests, then building and deploying the **confidential** (SCONE) version and testing it again.

![Flask Redis Demo](../docs/flask-redis.gif)

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
# Change into `flask-redis-netshield`.
cd flask-redis-netshield
# Create `certs` if it does not already exist.
mkdir -p certs

# CA
# Generate the certificate authority private key.
openssl genrsa -out certs/redis-ca.key 4096
# Create a self-signed certificate.
openssl req -x509 -new -nodes -key certs/redis-ca.key -sha256 -days 3650 \
  -out certs/redis-ca.crt -subj "/CN=redis-ca"

# Redis server cert
# Generate the Redis server private key.
openssl genrsa -out certs/redis.key 2048
# Create a certificate signing request.
openssl req -new -key certs/redis.key -out certs/redis.csr -subj "/CN=redis"
# Sign the certificate with the certificate authority.
openssl x509 -req -in certs/redis.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/redis.crt -days 365 -sha256

# Flask server cert
# Generate the Flask server private key.
openssl genrsa -out certs/flask.key 2048
# Create a certificate signing request.
openssl req -new -key certs/flask.key -out certs/flask.csr -subj "/CN=flask-api"
# Sign the certificate with the certificate authority.
openssl x509 -req -in certs/flask.csr -CA certs/redis-ca.crt -CAkey certs/redis-ca.key \
  -CAcreateserial -out certs/flask.crt -days 365 -sha256

# Client cert (used by Flask to connect to Redis)
# Generate the client private key.
openssl genrsa -out certs/client.key 2048
# Create a certificate signing request.
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=flask-client"
# Sign the certificate with the certificate authority.
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

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Then let `tplenv` query all environment variables used by this example:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Then build and push the native Docker image:

```bash
# Build the container image.
docker build -t ${IMAGE_NAME} .
# Push the container image to the registry.
docker push ${IMAGE_NAME}
```

---

### Step 3. Create the namespace

We try to ensure the namespace exists. This may fail when running in a container that is already in the target namespace, so we ignore that failure.

```bash
# Create the Kubernetes namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2> /dev/null || echo "Patching of namespace ${NAMESPACE}  failed -- ignoring this"
```

---

### Step 4. Generate and inspect secret manifests

Generate the secret YAML files locally so you can inspect them before applying:

```bash
# Generate the Kubernetes secret manifest.
kubectl create secret generic redis-tls \
  --namespace ${NAMESPACE} \
  --from-file=redis.crt=certs/redis.crt \
  --from-file=redis.key=certs/redis.key \
  --from-file=redis-ca.crt=certs/redis-ca.crt \
  --dry-run=client -o yaml > k8s/secret-redis-tls.yaml

# Generate the Kubernetes secret manifest.
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
# Apply the Kubernetes manifest.
kubectl apply -f k8s/secret-redis-tls.yaml
# Apply the Kubernetes manifest.
kubectl apply -f k8s/secret-flask-tls.yaml
```

---

### Step 5. Add Docker Registry Secret to Kubernetes

A pull secret is needed to pull both the native and confidential container images. Use `tplenv` to supply the registry credentials — it will prompt for any values not yet present in `Values.yaml`:

- `$REGISTRY` — the registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` — your registry login name
- `$REGISTRY_TOKEN` — your registry pull token (see [how to create a token](https://sconedocs.github.io/registry/))

We create the pull secret in the namespace if it does not yet exist:

```bash
# Check whether the pull secret already exists.
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # Load environment variables from the tplenv definition file.
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

---

### Step 6. Generate the manifest from the template

```bash
# Render the template with the selected values.
tplenv --file k8s/manifest.template.yaml --create-values-file --output k8s/manifest.yaml
```

Review `k8s/manifest.yaml`, then apply it:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f k8s/manifest.yaml --namespace ${NAMESPACE}
```

---

### Step 7. Verify the native deployment

```bash
# Watch all resources come up
# List the Kubernetes resources in the namespace.
kubectl get all -n ${NAMESPACE}

# Wait for Redis
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/redis -n ${NAMESPACE}  --watch=true  --timeout=240s

# Wait for Flask API
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --watch=true  --timeout=240s

# Check logs
# Show logs from the Kubernetes workload.
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
# Show logs from the Kubernetes workload.
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
```

---

### Step 8. Test the native API via port-forward

Open a port-forward to the Flask API pod:

```bash
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
# Capture the name of a ready pod for port-forwarding.
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
    | select(.metadata.deletionTimestamp == null)
    | select(.status.phase=="Running")
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
    | .metadata.name' | head -n1)


# Start a local port-forward to the Kubernetes workload.
kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid
```

Then send requests to `http://localhost:14996`. Note that we are only using `http` (and not yet `https`):

```bash
# List all stored keys
# Request the list of stored keys from the service.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/keys

# Create a client record
# Create a test client record through the API.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -X POST http://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
# Fetch the stored client record from the API.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/client/abc123

# Get credit score
# Request the credit score for the test client.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/score/abc123

# Memory dump (debug)
# Request the debug memory dump from the API.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/memory
```


---

### Step 9. Tear down the native deployment

Remove the native workloads and secrets before switching to the confidential version:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f k8s/manifest.yaml --namespace ${NAMESPACE} --ignore-not-found
# Delete the Kubernetes resource if it exists.
kubectl delete secret redis-tls flask-tls --namespace ${NAMESPACE} --ignore-not-found
```

---

## Part 2 — Confidential Deployment (SCONE)

### Step 10. Build the confidential (SCONE) images

When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. `scone-td-build` assumes, by default, that this key is stored in file `identity.pem`. We can generate this file as follows:

- we first check if the file exists, and
- if it does not exist, we create it with `openssl`

```bash
# Check whether the signing key needs to be generated.
if [ ! -f identity.pem ]; then
  # Print a status message.
  echo "Generating identity.pem ..."
  # Generate the signing key for confidential binaries.
  openssl genrsa -3 -out identity.pem 3072
else
  # Print a status message.
  echo "identity.pem already exists."
fi
```

Generate the SCONE config from its template, then run `scone-td-build` to produce hardened confidential images for both Redis and Flask and push them to the registry:

```bash
# Render the template with the selected values.
tplenv --file scone.template.yaml --create-values-file --output scone.yaml --indent
# Remove `flask-redis-demo.json` if it exists.
rm flask-redis-demo.json || true
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y scone.yaml
```

---

### Step 11. Deploy the confidential version

Apply the production sanitized manifest that references the SCONE confidential images:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifest.prod.sanitized.yaml --namespace ${NAMESPACE}
```

---

### Step 12. Verify the confidential deployment

```bash
# Watch all resources come up
# List the Kubernetes resources in the namespace.
kubectl get all -n ${NAMESPACE}

# Wait for Redis
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/redis -n ${NAMESPACE} --timeout=300s

# Wait for Flask API
# Wait for the deployment rollout to complete.
kubectl rollout status deployment/flask-api -n ${NAMESPACE} --timeout=300s

# Check logs
# Show logs from the Kubernetes workload.
kubectl logs -n ${NAMESPACE} -l app=flask-api --tail=50
# Show logs from the Kubernetes workload.
kubectl logs -n ${NAMESPACE} -l app=redis --tail=20
```

---

### Step 13. Test the confidential API via port-forward

Open a port-forward to the confidential Flask API pod:

```bash
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-14996.pid 2> /dev/null) 2> /dev/null || true
# Capture the name of a ready pod for port-forwarding.
POD=$(kubectl get pods -n ${NAMESPACE} -l app=flask-api -o json \
 | jq -r '.items[]
    | select(.metadata.deletionTimestamp == null)
    | select(.status.phase=="Running")
    | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))
    | .metadata.name' | head -n1)

# Start a local port-forward to the Kubernetes workload.
kubectl port-forward -n ${NAMESPACE} pod/$POD 14996:4996 & echo $! > /tmp/pf-14996.pid
```

Then send requests against `https://localhost:14996`:

```bash
# List all stored keys
# Request the list of stored keys from the service.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/keys

# Create a client record
# Create a test client record through the API.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 -X POST http://localhost:14996/client/abc123 \
  -F fname=John \
  -F lname=Doe \
  -F address="123 Main St" \
  -F city="Springfield" \
  -F iban="DE89370400440532013000" \
  -F ssn="123-45-6789" \
  -F email="john@example.com"

# Retrieve a client
# Fetch the stored client record from the API.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/client/abc123

# Get credit score
# Request the credit score for the test client.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/score/abc123

# Memory dump (debug)
# Request the debug memory dump from the API.
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 http://localhost:14996/memory
```

---

## Cleanup

Remove all deployed resources when you are finished:

```bash
# Stop the port-forward
# Stop the previous background process if it is still running.
kill $(cat /tmp/pf-14996.pid) 2> /dev/null || true
# Remove `/tmp/pf-14996.pid` if it exists.
rm /tmp/pf-14996.pid

# Delete confidential manifest resources
# Delete the Kubernetes resource if it exists.
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
