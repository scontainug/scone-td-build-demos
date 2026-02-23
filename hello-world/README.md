# Hello World Demo

## How to Run the Demo

### 1. Prerequisites

- A token for accessing `scone.cloud` images on registry.scontain.com
- A Kubernetes cluster
- The Kubernetes command line tool (`kubectl`)

#### 2. Set up the environment

Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).

#### 3. Build and Register Image

First, we build a simple cloud-native `hello world` image. For that we use Rust. Rust is available as a container image `rust:latest` on Dockerhub. We define a `Dockerfile` that uses this Rust image to create a `hello world` image:

- it creates a new Rust crate using `cargo`
- the new crate is actually defining a `hello world` program
- we build this project and push it to a repository to which we have push rights:

```bash
# change the following environment variable to an image repo
# to which you can push container images.
export IMAGE_NAME=registry.scontain.com/k8s-scone-images/hello-world:native
pushd hello-world

cargo new hello-world

docker build -t $IMAGE_NAME .
```

```
docker push $IMAGE_NAME
```

```bash
popd
```

We need to identify the programs that need to run confidential. To do so, we identify all programs on an image. To reduce the number of images, we have the following optimization:

- we determine all programs of a base image: we call this image the  `unprotected-image`
- we determine all programs of the container image used by the cloud-native application:  we call this image the `protected-image`

Only programs that are in the `protected-image` but not in the `unprotected-image` are considered to run confidential.

We register a new image for a later manifest translation. Our translation generates a new image that is the original image name extended by postfix `-scone`.

```bash
scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json

docker push $IMAGE_NAME-scone
```

#### 4. Create a secret for the image registry

```bash
# Fill in your credentials
kubectl create secret docker-registry scontain --docker-server=registry.scontain.com --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
```

#### 5. Convert the manifests

> If you already used `./install.sh` change `./target/debug/k8s-scone` to `k8s-scone`
> do not forget to enable port-forward for k8s-scone to talk to your CAS

```bash
./target/debug/k8s-scone apply -f ./examples/demo/hello-world/manifest.job.yaml -c cas.default -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0
```

#### 7. Apply the new manifest

```bash
kubectl apply -f examples/demo/hello-world/manifest.job.cleaned.yaml

kubectl logs job/hello-world
```

#### 8. Uninstall `hello-world`

```bash
kubectl delete -f examples/demo/hello-world/manifest.job.cleaned.yaml
```
