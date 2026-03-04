# NetworkPolicy

This guide shows how to build, deploy, and test the **NetworkPolicy demo** using `k8s-scone`. You will build client and server images, generate SCONE-protected images, apply the Kubernetes manifests, and verify that everything works as expected.

______________________________________________________________________

## 🧱 Normal Setup

Make sure you have the following tools installed and configured:

- Docker
- Kubernetes cluster (with `kubectl` configured)
- `scone-td-build` built locally
- Access to a container registry where you can push images

Navigate to the NetworkPolicy demo directory:

```bash
cd network-policy
```
______________________________________________________________________

## 🐳 Build Images

First, define the names of the Docker images that will be used for the demo. Hence, `tplenv` will now ask for all environment variables described in `environment-variables.md`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
```


### Build and push the base images

```bash
docker build -t $SERVER_IMAGE "server/"
docker build -t $CLIENT_IMAGE "client/"

docker push $SERVER_IMAGE
docker push $CLIENT_IMAGE
```

### Generate SCONE images

Create the SCONE configuration from the template and apply it using `k8s-scone`:

```bash
tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"
tplenv --file "./scone.template.yaml" --output "./scone.yaml"
scone-td-build from -y ./scone.yaml
```

This will generate SCONE-protected variants of both images.

Push the generated SCONE images:

```bash
docker push $SERVER_IMAGE-scone
docker push $CLIENT_IMAGE-scone
```

______________________________________________________________________

## 🚀 Apply Kubernetes Manifests

Deploy the application and NetworkPolicy configuration to the cluster:

```bash
kubectl apply -f "manifest.prod.sanitized.yaml"
```

Wait until all pods are running before continuing.

______________________________________________________________________

## ✅ Test the Setup

Forward the server service port to your local machine:

```bash
kubectl  wait --for=condition=Ready pod -l app="server" --timeout=240s
# being ready does not mean that port is available
sleep 20

kubectl port-forward svc/barad-dur 3000 &  echo $! > /tmp/pf-3000.pid
```

Send a request to the server:

```bash
curl localhost:3000/db-query
```

### Expected Result

The request should return a **random 7-character password**, confirming that:

- The application is running correctly
- The SCONE-protected images are working
- NetworkPolicy rules allow the intended traffic

9. **Uninstall the demo**

```bash
kubectl delete -f manifest.prod.sanitized.yaml
kill $(cat /tmp/pf-3000.pid) || true
rm /tmp/pf-3000.pid
popd
```
