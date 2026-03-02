# 🛡️ SCONE: Hello World

## Steps to Run the Hello World Program

![Hello-World Example](../docs/hello-world.gif)

### 1. Prerequisites

- A token for accessing `scone.cloud` images on registry.scontain.com
- A Kubernetes cluster
- The Kubernetes command line tool (`kubectl`)
- Rust `cargo` is installed (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)

#### 2. Set up the environment

Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).

#### 3. Setting up the Environment Variables

We build a simple cloud-native `hello world` image. For this, we use Rust. Rust is available as the container image `rust:latest` on Docker Hub. We define a `Dockerfile` that uses this image to create a `hello world` image:

- it creates a new Rust crate using `cargo`
- the new crate is actually defining a `hello world` program
- we build this project and push it to a repository where we have push access:

```bash
# Ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.
pushd hello-world
export CONFIRM_ALL_ENVIRONMENT_VARIABLES=""
```

The default values of several environment variables are defined in file `Values.yaml`.
`tplenv` asks whether all defaults are okay. It then sets the environment variables:

 - `$IMAGE_NAME` - name of the native container image to deploy the `hello-world` application,
 - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image
 - `$IMAGE_PULL_SECRET_NAME` - the name of the pull secret used to pull this image (default: `sconeapps`). For simplicity, we assume we can use the same pull secret for both the native and confidential workloads.
 - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1 for now) 
 - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)
 - `$CAS_NAME` - The CAS name to use (e.g., `cas`) 
 - `$CVM_MODE` - if you want CVM mode, set it to `--cvm`. For SGX, leave it empty.
 - `$SCONE_ENCLAVE` - in CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata Pods (leave it empty).

Program `tplenv` asks the user whether to keep the current (default) configuration stored in `Values.yaml`.
The user can modify the configuration if needed by setting the following variable to `--force`.
Replace the `--force` by `""` to only ask for variables that are not defined in the environment
or the `Values.yaml` file. Note that `Values.yaml` has priority over environment variables.
If the user changes values, they are written to `Values.yaml`.

Ensure that we ask the user to confirm or modify all environment variables:

```
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
```

`tplenv` will now ask for all environment variables described in `environment-variables.md`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )
```

We encrypt the policies that we send to CAS to ensure the integrity and confidentiality of the policies. To do so, we need to attest the CAS. We do this using a plugin of `kubectl` that attests the CAS via the Kubernetes API:

```bash
# attest the CAS - to ensure that we know the correct session encryption key
kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}
```

In case the attestation and verification of the CAS would fail, please read the output of `kubectl scone cas attest` to determine which vulnerabilities were detected. It also suggests which options to pass to `kubectl scone cas attest` to tolerate these vulnerabilities, i.e., to make the attestation and verification to succeed.

Next, we need to customize the job manifest to set the right image name (`$IMAGE_NAME`) and the right pull secret (`$IMAGE_PULL_SECRET_NAME`):

```bash
# customize the job manifest
tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml
```

#### 4. Build and Register Image

Now we create the native `hello-world` application using Rust. Note that we could create the `hello-world` program inside the `Dockerfile` (see below) used to build the native container image. To keep this example easy to customize, we create the Rust files directly.

```bash
# create the hello-world application
cargo new hello-world || echo "Hello World already exists - using existing one"
```

We compile the application within a Rust image:

```bash
# build the hello-world app in a Container
docker build -t $IMAGE_NAME .
```

If you have permission to push to `$IMAGE_NAME`, push the container image. If you use the default image name, you can use the pre-built container image (that is, there is no need to push the image).

```
docker push $IMAGE_NAME
```

## 5. Sconifying the Application

We need to identify the programs that must run confidentially. To do so, we identify all programs in the image that might run confidentially. We can explicitly specify all binaries that must be confidential by using the following options for `scone-td-build register`:

-  `--enforce <ENFORCE>` 
          Set enforced binaries to ensure that these binaries in the protected image are executed confidentially in the destination image. To define multiple binaries, use this flag multiple times.

- `--enforce-list <ENFORCE_LIST>`
          Specify a file that contains a list of binary filenames in the protected image. All binaries in the list will run confidentially in the destination image.

Alternatively, we could assume that all binaries might run confidentially. That might result in many programs being transformed. To reduce the number of binaries that need to be transformed and the effort of specifying all confidential binaries, we use the following approach:

- `scone-td-build register` first determines all programs of a base image: we call this image the  `unprotected-image`
- `scone-td-build register` then determines all programs of the container image used by the cloud-native application:  we call this image the `protected-image`

We register a new image for later manifest translation: the manifest is protected so that a Kubernetes cluster admin cannot modify or read an application's `ConfigMaps` and `Secrets`.

Our translation generates a new image by appending the suffix `-scone` to the original image name, unless we define a new image name with `--destination-image`:

```bash
scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}
```

Registering images allows us to copy images into our own repository. This decouples our application from changes in the upstream repository that contains the original container image (in this case, `$IMAGE_NAME`).

#### 6. Create a Pull Secret

We assume you need a pull secret to pull both the native and confidential container images. First, we check whether the pull secret is already set. If it is not, we ask the user for the information needed to create it:

- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.
- `$REGISTRY_USER` - the login name of the user that pulls the container image.
- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.

Note that `tplenv` stores this information in `Values.yaml`.

```bash
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # ask user for the credentials for accessing the registry
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force )
  kubectl create secret docker-registry scontain --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi
```

#### 7. Convert the manifests

Next, we use the native Kubernetes manifests and transform them into *sanitized* manifests.

```bash
scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  ${CVM_MODE} ${SCONE_ENCLAVE}
```

#### 8. Apply the new manifest

```bash
# Ensure that previous run is not running anymore
kubectl delete job hello-world || echo "ok - no previous job that we need to delete"
kubectl apply -f manifest.job.cleaned.yaml
```

We need to wait briefly before the job logs become available. Therefore, we execute the command within the `retry-spinner` retry wrapper:

Let's see the output of the job

```bash
retry-spinner -- kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps
```

#### 9. Uninstall `hello-world`

Delete the job that we just created:

```bash
kubectl delete job hello-world 
popd
```

### Automation

You can execute the steps in this document automatically by running `./scripts/hello-world.sh`. Note that this will not ask for user input; it will use the configuration in `hello-world/Values.yaml`.

If you update the commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.
