# NetworkPolicy

This guide shows how to build, deploy, and test the **NetworkPolicy demo** using `k8s-scone`. You will build client and server images, generate SCONE-protected images, apply the Kubernetes manifests, and verify that everything works as expected.

______________________________________________________________________

## 🧱 Normal Setup

Make sure you have the following tools installed and configured:

- Docker
- Kubernetes cluster (with `kubectl` configured)
- `k8s-scone` built locally
- Access to a container registry where you can push images

______________________________________________________________________

## 🐳 Build Images

First, define the names of the Docker images that will be used for the demo:

```bash
export DEMO_CLIENT_IMAGE=<CLIENT_IMAGE_NAME>
export DEMO_SERVER_IMAGE=<SERVER_IMAGE_NAME>
```

> 💡 These should be full image names, including the registry (for example: `docker.io/youruser/demo-client`).

Navigate to the NetworkPolicy demo directory:

```bash
cd demo/examples/networkPolicy
```

### Build and push the base images

```bash
docker build -t $DEMO_SERVER_IMAGE "server/"
docker build -t $DEMO_CLIENT_IMAGE "client/"

docker push $DEMO_SERVER_IMAGE
docker push $DEMO_CLIENT_IMAGE
```

### Generate SCONE images

Create the SCONE configuration from the template and apply it using `k8s-scone`:

```bash
envsubst < "./scone.template.yaml" > "./scone.yaml"
./target/debug/k8s-scone from -y ./scone.yaml
```

This will generate SCONE-protected variants of both images.

Push the generated SCONE images:

```bash
docker push $DEMO_SERVER_IMAGE-scone
docker push $DEMO_CLIENT_IMAGE-scone
```

______________________________________________________________________

## 🚀 Apply Kubernetes Manifests

Deploy the application and NetworkPolicy configuration to the cluster:

```bash
kubectl apply -f "demo/examples/networkPolicy/manifest.prod.sanitized.yaml"
```

Wait until all pods are running before continuing.

______________________________________________________________________

## ✅ Test the Setup

Forward the server service port to your local machine:

```bash
kubectl port-forward svc/barad-dur 3000 &
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
