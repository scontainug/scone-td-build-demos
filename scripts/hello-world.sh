#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# 🛡️ SCONE: Hello World'
printf '%s\n' ''
printf '%s\n' '## Steps to Run the Hello World Program'
printf '%s\n' ''
printf '%s\n' '![Hello-World Example](../docs/hello-world.gif)'
printf '%s\n' ''
printf '%s\n' 'We build a simple cloud-native `hello world` application. For this, we use Rust. Rust is available as the container image `rust:latest` on Docker Hub. We define a `Dockerfile` to create a `hello world` image:'
printf '%s\n' ''
printf '%s\n' '- it creates a new Rust crate using `cargo`'
printf '%s\n' '  - the new crate is actually defining a `hello world` program'
printf '%s\n' '- we build this project and push it to a repository where we have push access:'
printf '%s\n' ''
printf '%s\n' 'We assume we start in `scone-td-build-demos`. We need to ensure that we are in the correct directory for this example:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'pushd hello-world'
printf "${RESET}"

pushd hello-world

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '### 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' 'We assume that you set up your tooling:'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster containing either SGX- oder SCONE-devices.'
printf '%s\n' '- The Kubernetes command line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` is installed (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install these tools:'
printf '%s\n' ''
printf '%s\n' ' - to set up the tools on your VM / laptop, follow this guide: [prerequisite_check.md](https://github.com/scontain/scone/blob/main/prerequisite_check.md).  '
printf '%s\n' ' - The simplest way is to install the tools in a Kubernetes cluster follow this guide: [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '#### 2. Setting up the Environment Variables'
printf '%s\n' ''
printf '%s\n' 'We use the following environment variables in this example. For the cloud-native variant, we only need to define the following variables:'
printf '%s\n' ''
printf '%s\n' ' - `$IMAGE_NAME` - name of the native container image to deploy the `hello-world` application,'
printf '%s\n' ' - `$IMAGE_PULL_SECRET_NAME` - the name of the pull secret used to pull this image (default: `sconeapps`). For simplicity, we assume we can use the same pull secret for both the native and confidential workloads.'
printf '%s\n' ''
printf '%s\n' 'For the confidential, cloud-native application, we need to define more variables:'
printf '%s\n' ''
printf '%s\n' ' - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image'
printf '%s\n' ' - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1 for now) '
printf '%s\n' ' - `$CAS_NAMESPACE` - the Kubernetes namespace of CAS (SCONE Configuration and Attestation Service) (e.g., `default`)'
printf '%s\n' ' - `$CAS_NAME` - The Kubernetes name of CAS that we want to use (e.g., `cas`)'
printf '%s\n' ' - `$CVM_MODE` - if you want CVM mode, set it to `--cvm`. For SGX, leave it empty.'
printf '%s\n' ' - `$SCONE_ENCLAVE` - in CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata Pods (leave it empty).'
printf '%s\n' ''
printf '%s\n' 'The default values of these environment variables are defined in file `Values.yaml`. To simplify the customization, we use a convenience tool [`tplenv`](https://github.com/scontainug/tplenv) that asks whether all defaults are okay:'
printf '%s\n' ''
printf '%s\n' '- Program `tplenv` asks the user whether to keep the current (default) configuration stored in `Values.yaml`. It uses environment variables to preset the values in case they are not yet defined in `Values.yaml`: Note that `Values.yaml` has priority over environment variables.'
printf '%s\n' ''
printf '%s\n' 'If the user changes values, they are written to `Values.yaml`. `tplenv` will now ask for all environment variables described in `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Next, we customize the job manifest to set the right image name (`$IMAGE_NAME`) and the right pull secret (`$IMAGE_PULL_SECRET_NAME`):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# customize the job manifest'
printf '%s\n' 'tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml'
printf "${RESET}"

# customize the job manifest
tplenv --file manifest.job.template.yaml --create-values-file --output  manifest.job.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 3. Build Native Container Image'
printf '%s\n' ''
printf '%s\n' 'Now we create the native `hello-world` application using Rust. Note that we could create the `hello-world` program inside the `Dockerfile` (see below) used to build the native container image. To keep this example easy to customize, we create the Rust files directly.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# create the hello-world application'
printf '%s\n' 'cargo new hello-world || echo "Hello World already exists - using existing one"'
printf "${RESET}"

# create the hello-world application
cargo new hello-world || echo "Hello World already exists - using existing one"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We compile the application within a Rust image:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# build the hello-world app in a Container'
printf '%s\n' 'docker build -t $IMAGE_NAME .'
printf "${RESET}"

# build the hello-world app in a Container
docker build -t $IMAGE_NAME .

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'If you have permission to push to `$IMAGE_NAME`, push the container image. If you use the default image name, you can use the pre-built container image (that is, there is no need to push the image).'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'docker push $IMAGE_NAME'
printf "${RESET}"

docker push $IMAGE_NAME

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 4. Create a Pull Secret'
printf '%s\n' ''
printf '%s\n' 'We assume you need a pull secret to pull both the native and confidential container images. First, we check whether the pull secret is already set. If it is not, we ask the user for the information needed to create it:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` - the name of the registry. By default, this is `registry.scontain.com`.'
printf '%s\n' '- `$REGISTRY_USER` - the login name of the user that pulls the container image.'
printf '%s\n' '- `$REGISTRY_TOKEN` - the token used to pull the image. See <https://sconedocs.github.io/registry/> for how to create this token.'
printf '%s\n' ''
printf '%s\n' 'We ask the user for the values of these environment variables using `tplenv` and file `registry.credentials.md` which introduces these three variables. Note that `tplenv` stores this information in `Values.yaml`.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"'
printf '%s\n' 'else'
printf '%s\n' '  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."'
printf '%s\n' '  # ask user for the credentials for accessing the registry'
printf '%s\n' '  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )'
printf '%s\n' '  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN'
printf '%s\n' 'fi'
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  # ask user for the credentials for accessing the registry
  eval $(tplenv --file registry.credentials.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} )
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" --docker-server=$REGISTRY --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_TOKEN
fi

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 5. Run the Native Hello-World Application'
printf '%s\n' ''
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure that previous run is not running anymore'
printf '%s\n' 'kubectl delete job hello-world || echo "ok - no previous job that we need to delete"'
printf '%s\n' 'kubectl apply -f manifest.job.yaml'
printf "${RESET}"

# Ensure that previous run is not running anymore
kubectl delete job hello-world || echo "ok - no previous job that we need to delete"
kubectl apply -f manifest.job.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'First, we wait for the job logs to become available before we can show the output of the job:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl wait --for=condition=complete job/hello-world --timeout=300s'
printf '%s\n' 'kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

kubectl wait --for=condition=complete job/hello-world --timeout=300s
kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Finally, we delete the job and wait for the pod to terminate:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete job hello-world'
printf '%s\n' 'kubectl wait --for=delete pod -l app=hello-world --timeout=300s'
printf "${RESET}"

kubectl delete job hello-world
kubectl wait --for=delete pod -l app=hello-world --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 4. Attesting SCONE CAS (Configuration and Attestation Service)'
printf '%s\n' ''
printf '%s\n' 'We encrypt the policies that we send to CAS to ensure the integrity and confidentiality of the policies. To do so, we need to attest and verify the CAS:'
printf '%s\n' ''
printf '%s\n' '- we need to learn that we can trust the CAS'
printf '%s\n' ''
printf '%s\n' 'We do this using a plugin of `kubectl` that attests the CAS via the Kubernetes API:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# attest the CAS - to ensure that we know the correct session encryption key'
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME} -C -G -S'
printf "${RESET}"

# attest the CAS - to ensure that we know the correct session encryption key
kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME} -C -G -S

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'In case the attestation and verification of the CAS would fail, please read the output of `kubectl scone cas attest` to determine which vulnerabilities were detected. It also suggests which options to pass to `kubectl scone cas attest` to tolerate these vulnerabilities, i.e., to make the attestation and verification succeed even if the hardware and firmware is out-of-date.'
printf '%s\n' ''
printf '%s\n' '## 5. Sconifying the Application'
printf '%s\n' ''
printf '%s\n' 'We need to identify the programs that must run confidentially. To do so, we identify all programs in the image that might run confidentially. We can explicitly specify all binaries that must be confidential by using the following options for `scone-td-build register`:'
printf '%s\n' ''
printf '%s\n' '-  `--enforce <ENFORCE>` '
printf '%s\n' '          Set enforced binaries to ensure that these binaries in the protected image are executed confidentially in the destination image. To define multiple binaries, use this flag multiple times.'
printf '%s\n' ''
printf '%s\n' '- `--enforce-list <ENFORCE_LIST_FILE>`'
printf '%s\n' '          Specify a file that contains a list of binary filenames in the protected image. All binaries in the list will run confidentially in the destination image.'
printf '%s\n' ''
printf '%s\n' 'Alternatively, we could assume that all binaries might run confidentially. That might result in many programs being transformed. To reduce the number of binaries that need to be transformed and the effort of specifying all confidential binaries, we use the following approach:'
printf '%s\n' ''
printf '%s\n' '- `scone-td-build register` first determines all programs of a base image: we call this image the  `unprotected-image`'
printf '%s\n' '- `scone-td-build register` then determines all programs of the container image used by the cloud-native application:  we call this image the `protected-image`'
printf '%s\n' ''
printf '%s\n' 'We register a new image and we use this later in the context of the transformation of the Kuberentes manifests: the manifests are protected so that a Kubernetes cluster admin cannot modify or read an application'\''s `ConfigMaps` and `Secrets`.'
printf '%s\n' ''
printf '%s\n' 'Our translation generates a new image by appending the suffix `-scone` to the original image name, unless we define a new image name with `--destination-image`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}'
printf "${RESET}"

scone-td-build register --protected-image $IMAGE_NAME --unprotected-image rust:latest --manifest-env SCONE_PRODUCTION=0 -s ./storage.json --destination-image ${DESTINATION_IMAGE_NAME} --push --version ${SCONE_VERSION} ${CVM_MODE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Registering images allows us to copy images into our own repository. This decouples our application from changes in the upstream repository that contains the original container image (in this case, `$IMAGE_NAME`).'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '#### 7. Transforming the Kubernetes manifests'
printf '%s\n' ''
printf '%s\n' 'Next, we use the native Kubernetes manifests and transform them into *sanitized* manifests.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  --manifest-env SCONE_VERSION=1 ${CVM_MODE} ${SCONE_ENCLAVE}'
printf "${RESET}"

scone-td-build apply -f manifest.job.yaml -c ${CAS_NAME}.${CAS_NAMESPACE} -p -s ./storage.json --manifest-env SCONE_SYSLIBS=1 --manifest-env SCONE_PRODUCTION=0  --manifest-env SCONE_VERSION=1 ${CVM_MODE} ${SCONE_ENCLAVE}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '#### 8. Apply the new manifest'
printf '%s\n' ''
printf '%s\n' 'The manifests are uploaded as we upload native manifests:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.job.cleaned.yaml'
printf "${RESET}"

kubectl apply -f manifest.job.cleaned.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'First, we wait for the job logs to become available before we can show the output of the job:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl wait --for=condition=complete job/hello-world --timeout=300s'
printf '%s\n' 'kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps'
printf "${RESET}"

kubectl wait --for=condition=complete job/hello-world --timeout=300s
kubectl logs job/hello-world --follow --pod-running-timeout=2m --timestamps

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Finally, we delete the job and wait for the pod to terminate:'
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '#### 9. Uninstall `hello-world`'
printf '%s\n' ''
printf '%s\n' 'Delete the job that we just created:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete job hello-world'
printf '%s\n' 'kubectl wait --for=delete pod -l app=hello-world --timeout=300s'
printf "${RESET}"

kubectl delete job hello-world
kubectl wait --for=delete pod -l app=hello-world --timeout=300s

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'and return to the previous directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'popd'
printf "${RESET}"

popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '### Automation'
printf '%s\n' ''
printf '%s\n' 'You can execute the steps in this document automatically by running `./scripts/hello-world.sh`. Note that this will not ask for user input; it will use the configuration in `hello-world/Values.yaml`.'
printf '%s\n' ''
printf '%s\n' 'If you update the commands in this document, run `./scripts/extract-all-scripts.sh` to regenerate `./scripts/hello-world.sh`.'
printf "${RESET}"

