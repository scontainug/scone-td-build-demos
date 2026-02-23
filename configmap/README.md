# 🛡️ SCONE ConfigMap Demo: Secure Your App Configs in Kubernetes

This demo walks you through how to securely manage and access configuration data in Kubernetes using a `ConfigMap` and a SCONE-enabled Rust application. You’ll start with a plain (unencrypted) deployment, then transition to a fully protected SCONE deployment.

______________________________________________________________________

## ✅ Requirements

Ensure you have the following:

- [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
- A Kubernetes cluster **with SGX support** (e.g., AKS with Intel SGX, or a local SGX-compatible setup like `k3d`)
- [Rust](https://www.rust-lang.org/)
- `gcc-multilib` (required by SCONE toolchain)
- Access to a SCONE-compatible container registry (e.g., `registry.scontain.com`)

______________________________________________________________________

## 🧱 1. Build the Native Rust Image

This step builds a native (unencrypted) version of the image to validate behavior before enforcing protection with SCONE.

```bash

pushd examples/demo/configmap/folder-reader

// Insert the name of your image
export DEMO_IMAGE=</IMAGE_NAME>
docker build -t ${DEMO_IMAGE} .
docker push ${DEMO_IMAGE}

popd
```

______________________________________________________________________

## 🧩 Step 2: Render the Manifest

```bash
envsubst < ./examples/demo/configmap/manifest.template.yaml > ./examples/demo/configmap/manifest.yaml
envsubst < ./examples/demo/configmap/scone.template.yaml > ./examples/demo/configmap/scone.yaml
```

> Make sure the image name was correctly substituted in the manifest.native.yaml file before applying it with kubectl.

______________________________________________________________________

## 🔑 3. Add Docker Registry Secret to Kubernetes

```bash
kubectl create secret docker-registry scontain \
  --docker-server=registry.scontain.com \
  --docker-username=$REGISTRY_USER \
  --docker-password=$REGISTRY_TOKEN
```

______________________________________________________________________

## 🧪 4. Deploy the Native App [OPTIONAL]

```bash
kubectl apply -f examples/demo/configmap/manifest.yaml

kubectl logs job/my-rust-app -c reader-1
kubectl logs job/my-rust-app -c reader-2

# Clean up native app
kubectl delete -f examples/demo/configmap/manifest.yaml
```

✅ Your containers should log content from their mounted ConfigMap files.

______________________________________________________________________

## 🧩 5. Prepare and Apply the SCONE Manifest

```
./target/debug/k8s-scone from -y ./examples/demo/configmap/scone.yaml

docker push ${DEMO_IMAGE}-scone
```

This step:

- Generates a SCONE session
- Attaches it to your manifest
- Produces a new `./manifest.prod.sanitized.yaml` with the necessary information to use the created session

______________________________________________________________________

## 🚀 6. Deploy the SCONE-Protected App

```bash
kubectl apply -f ./manifest.prod.sanitized.yaml
```

______________________________________________________________________

## 📜 7. View Logs

Check that SCONE-protected containers can access the expected ConfigMap data:

```bash
watch 'kubectl logs job/my-rust-app -c reader-1'
kubectl logs job/my-rust-app -c reader-2
```

______________________________________________________________________

## 🧹 8. Clean Up

```bash
kubectl delete -f ./manifest.prod.sanitized.yaml
```
