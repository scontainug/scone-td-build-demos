# NetworkPolicy

This guide explains how to build, deploy, and test the **NetworkPolicy demo** with `scone-td-build`. You will build client and server images, generate SCONE-protected images, apply Kubernetes manifests, and verify the result.

![Network Policy Demo](../docs/network-policy.gif)

## 1. Prerequisites

Make sure you have:

- Docker
- A Kubernetes cluster with `kubectl` configured
- `tplenv`
- `scone-td-build` built locally
- Access to a container registry where you can push images

Switch to the demo directory:

```bash
cd network-policy
rm -f netshield.json || true
```

## 2. Build Images

Initialize environment variables from `environment-variables.md` using `tplenv`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

Build and push native images:

```bash
docker build -t $SERVER_IMAGE "server/"
docker build -t $CLIENT_IMAGE "client/"

docker push $SERVER_IMAGE
docker push $CLIENT_IMAGE
```

## 3. Generate SCONE Images

Create SCONE config files from templates, then run `scone-td-build`:

```bash
tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"
tplenv --file "./scone.template.yaml" --output "./scone.yaml"
scone-td-build from -y ./scone.yaml
```

Push the generated SCONE images:

```bash
docker push $SERVER_IMAGE-scone
docker push $CLIENT_IMAGE-scone
```

## 4. Apply Kubernetes Manifests

```bash
kubectl apply -f "manifest.prod.sanitized.yaml"
```

Wait until all pods are running before continuing.

## 5. Test the Setup

Wait for pods and port-forward the server service:

```bash
kubectl wait --for=condition=Ready pod -l app="server" --timeout=300s
kubectl wait --for=condition=Ready pod -l app="client" --timeout=300s
# A ready pod does not always mean the port is immediately available.
sleep 10

kubectl port-forward svc/barad-dur 3000 & echo $! > /tmp/pf-3000.pid
```

Send requests:

```bash
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
```

Expected result: a random 7-character password, which confirms:

- The application is running correctly
- SCONE-protected images are working
- NetworkPolicy rules allow intended traffic

## 6. Uninstall the Demo

```bash
kubectl delete -f manifest.prod.sanitized.yaml
kill $(cat /tmp/pf-3000.pid) || true
rm /tmp/pf-3000.pid
cd -
```
