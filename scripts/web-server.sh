#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# Web Server Demo'
printf '%s\n' ''
printf '%s\n' '## Introduction'
printf '%s\n' ''
printf '%s\n' 'This Rust application is a minimal web service built with the [Axum](https://github.com/tokio-rs/axum) framework.'
printf '%s\n' 'While it is more functional than a traditional "web server" example, it remains straightforward and easy to understand.'
printf '%s\n' ''
printf '%s\n' '![Web-Server Example](../docs/web-server.gif)'
printf '%s\n' ''
printf '%s\n' '## Endpoints'
printf '%s\n' ''
printf '%s\n' '- **Generate Password Endpoint (`/gen`)**:'
printf '%s\n' ''
printf '%s\n' '  - Generates a random password consisting of alphanumeric characters.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "password": "aBcD1234EeFgH5678"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print Path Endpoint (`/path`)**:'
printf '%s\n' ''
printf '%s\n' '  - Reads files from the `/config` directory and returns their names and contents.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "name": "file1.txt",'
printf '%s\n' '    "content": "This is the content of file1.txt.\n..."'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '- **Print Environment Variable Endpoint (`/env/:env`)**:'
printf '%s\n' ''
printf '%s\n' '  - Retrieves the value of the specified environment variable.'
printf '%s\n' '  - Example Response:'
printf '%s\n' ''
printf '%s\n' '  ```json'
printf '%s\n' '  {'
printf '%s\n' '    "value": "your_env_value_here"'
printf '%s\n' '  }'
printf '%s\n' '  ```'
printf '%s\n' ''
printf '%s\n' '## How to Run the Demo'
printf '%s\n' ''
printf '%s\n' '### 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on registry.scontain.com'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` is installed (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- You installed `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' ''
printf '%s\n' '#### 2. Set up the environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools. The simplest way is to install the tools in a Kubernetes cluster (see [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md)).'
printf '%s\n' ''
printf '%s\n' '#### 3. Setting up the Environment Variables'
printf '%s\n' ''
printf '%s\n' 'We build a simple cloud-native `web-server` image. For this, we use Rust. Rust is available as the container image `rust:latest` on Docker Hub. We define a `Dockerfile` that uses this image to create a `web-server` image:'
printf '%s\n' ''
printf '%s\n' '- it creates a new Rust crate using `cargo`'
printf '%s\n' '- the new crate defines the `web-server` program'
printf '%s\n' '- we build this project and push it to a repository where we have push access:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.'
printf '%s\n' 'pushd web-server'
printf "${RESET}"

# Ensure we are in the correct directory. We assume we start in `scone-td-build-demos`.
pushd web-server

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'The default values of several environment variables are defined in file `Values.yaml`.'
printf '%s\n' '`tplenv` asks whether all defaults are okay. It then sets the environment variables:'
printf '%s\n' ''
printf '%s\n' ' - `$IMAGE_NAME` - name of the native container image to deploy the `web-server` application,'
printf '%s\n' ' - `$DESTINATION_IMAGE_NAME` - destination of the confidential container image'
printf '%s\n' ' - `$IMAGE_PULL_SECRET_NAME` - the name of the pull secret used to pull this image (default: `sconeapps`). For simplicity, we assume we can use the same pull secret for both the native and confidential workloads.'
printf '%s\n' ' - `$SCONE_VERSION` - the SCONE version to use (7.0.0-alpha.1 for now) '
printf '%s\n' ' - `$CAS_NAMESPACE` - the CAS namespace to use (e.g., `default`)'
printf '%s\n' ' - `$CAS_NAME` - The CAS name to use (e.g., `cas`) '
printf '%s\n' ' - `$CVM_MODE` - if you want CVM mode, set it to `--cvm`. For SGX, leave it empty.'
printf '%s\n' ' - `$SCONE_ENCLAVE` - in CVM mode, you can run using confidential Kubernetes nodes (set to `--scone-enclave`) or Kata Pods (leave it empty).'
printf '%s\n' ''
printf '%s\n' 'Program `tplenv` asks the user whether to keep the current (default) configuration stored in `Values.yaml`.'
printf '%s\n' 'Note that `Values.yaml` has priority over environment variables.'
printf '%s\n' 'If the user changes values, they are written to `Values.yaml`.'
printf '%s\n' ''
printf '%s\n' '`tplenv` will now ask for all environment variables described in `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We encrypt the policies that we send to CAS to ensure the integrity and confidentiality of the policies. To do so, we need to attest the CAS. We do this using a plugin of `kubectl` that attests the CAS via the Kubernetes API:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# attest the CAS - to ensure that we know the correct session encryption key'
printf '%s\n' 'kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}'
printf "${RESET}"

# attest the CAS - to ensure that we know the correct session encryption key
kubectl scone cas attest --namespace ${CAS_NAMESPACE}  ${CAS_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'In case the attestation and verification of the CAS would fail, please read the output of `kubectl scone cas attest` to determine which vulnerabilities were detected. It also suggests which options to pass to `kubectl scone cas attest` to tolerate these vulnerabilities, i.e., to make the attestation and verification to succeed.'
printf '%s\n' ''
printf '%s\n' 'Next, we need to customize the job manifest to set the right image name (`$IMAGE_NAME`) and the right pull secret (`$IMAGE_PULL_SECRET_NAME`):'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# customize the job manifest'
printf '%s\n' 'tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml'
printf "${RESET}"

# customize the job manifest
tplenv --file manifest.template.yaml --create-values-file --output  manifest.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '4. **Register image**'
printf '%s\n' ''
printf '%s\n' 'Now, we create the native `web-server` application using Rust.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Build the Scone image for the demo client'
printf '%s\n' 'docker build -t ${IMAGE_NAME} .'
printf '%s\n' ''
printf '%s\n' '# Push it to the registry'
printf '%s\n' 'docker push ${IMAGE_NAME}'
printf "${RESET}"

# Build the Scone image for the demo client
docker build -t ${IMAGE_NAME} .

# Push it to the registry
docker push ${IMAGE_NAME}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'When transforming the binaries in the container image for confidential computing, we sign the binaries with a key. `scone-td-build` assumes, by default, that this key is stored in file `identity.pem`. We can generate this file as follows:'
printf '%s\n' ''
printf '%s\n' '- we first check if the file exists, and'
printf '%s\n' '- if it does not exist, we create it with `openssl`'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'if [ ! -f identity.pem ]; then'
printf '%s\n' '  echo "Generating identity.pem ..."'
printf '%s\n' '  openssl genrsa -3 -out identity.pem 3072'
printf '%s\n' 'else'
printf '%s\n' '  echo "identity.pem already exists."'
printf '%s\n' 'fi'
printf "${RESET}"

if [ ! -f identity.pem ]; then
  echo "Generating identity.pem ..."
  openssl genrsa -3 -out identity.pem 3072
else
  echo "identity.pem already exists."
fi

printf "${VIOLET}"
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build register \'
printf '%s\n' '    --protected-image ${IMAGE_NAME} \'
printf '%s\n' '    --unprotected-image ${IMAGE_NAME} \'
printf '%s\n' '    --destination-image ${DESTINATION_IMAGE_NAME} \'
printf '%s\n' '    --push \'
printf '%s\n' '    -s ./storage.json \'
printf '%s\n' '    --enforce /app/web-server \'
printf '%s\n' '    --version ${SCONE_VERSION}'
printf "${RESET}"

scone-td-build register \
    --protected-image ${IMAGE_NAME} \
    --unprotected-image ${IMAGE_NAME} \
    --destination-image ${DESTINATION_IMAGE_NAME} \
    --push \
    -s ./storage.json \
    --enforce /app/web-server \
    --version ${SCONE_VERSION}

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '5. **Test the manifest [optional]**'
printf '%s\n' ''
printf '%s\n' 'First, we clean up, just in case a previous version is running:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Make sure web-server does not yet run'
printf '%s\n' 'kubectl delete deployment web-server || echo "ok - no web-server deployment yet"'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
printf '%s\n' 'kill $(cat /tmp/pf-8000.pid) || true'
printf "${RESET}"

# Make sure web-server does not yet run
kubectl delete deployment web-server || echo "ok - no web-server deployment yet"
kubectl wait --for=delete pod -l app=web-server --timeout=240s
kill $(cat /tmp/pf-8000.pid) || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Second, we start the deployment.'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.yaml'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
printf '%s\n' ''
printf '%s\n' '# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps'
printf '%s\n' '# Use this command in another terminal, or run it in the background by appending `&`.'
printf '%s\n' 'kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid'
printf '%s\n' ''
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/env/MY_POD_IP'
printf '%s\n' './test.sh'
printf '%s\n' ''
printf '%s\n' 'kubectl delete -f manifest.yaml'
printf '%s\n' 'kubectl wait --for=delete pod -l app=web-server --timeout=240s'
printf '%s\n' ''
printf '%s\n' '# Close the port forward after execution'
printf '%s\n' 'kill $(cat /tmp/pf-8000.pid) || true'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf "${RESET}"

kubectl apply -f manifest.yaml
kubectl wait --for=condition=Ready pod -l app="web-server" --timeout=240s

# retry-spinner --retries 40 --wait 10 -- kubectl logs -l app=web-server --pod-running-timeout=2m --timestamps
# Use this command in another terminal, or run it in the background by appending `&`.
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid

retry-spinner -- curl http://localhost:8000/env/MY_POD_IP
./test.sh

kubectl delete -f manifest.yaml
kubectl wait --for=delete pod -l app=web-server --timeout=240s

# Close the port forward after execution
kill $(cat /tmp/pf-8000.pid) || true
rm /tmp/pf-8000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '6. **Convert the manifest**'
printf '%s\n' ''
printf '%s\n' 'If you want to see how the SCONE image was registered with `scone-td-build`, see [register-image](../../../register-image.md).'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'scone-td-build apply \'
printf '%s\n' '    -f manifest.yaml \'
printf '%s\n' '    -c ${CAS_NAME}.${CAS_NAMESPACE} \'
printf '%s\n' '    -s ./storage.json \'
printf '%s\n' '    --manifest-env SCONE_SYSLIBS=1 \'
printf '%s\n' '    --manifest-env SCONE_VERSION=1 \'
printf '%s\n' '    --session-env SCONE_VERSION=1 \'
printf '%s\n' '    --version ${SCONE_VERSION} -p'
printf "${RESET}"

scone-td-build apply \
    -f manifest.yaml \
    -c ${CAS_NAME}.${CAS_NAMESPACE} \
    -s ./storage.json \
    --manifest-env SCONE_SYSLIBS=1 \
    --manifest-env SCONE_VERSION=1 \
    --session-env SCONE_VERSION=1 \
    --version ${SCONE_VERSION} -p

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '7. **Deploy the new manifest**'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f manifest.cleaned.yaml'
printf "${RESET}"

kubectl apply -f manifest.cleaned.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '> For the next step, it is expected that you have a Kubernetes cluster with SGX resources and a running LAS.'
printf '%s\n' ''
printf '%s\n' '8. **Run the demo**'
printf '%s\n' ''
printf '%s\n' 'We wait for the pod to become ready before we try a port-forward to access the `web-server`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s'
printf '%s\n' '# being ready does not mean that port is available'
printf '%s\n' 'sleep 20'
printf '%s\n' ''
printf '%s\n' '# We keep the PID so we can stop the port-forward process later.'
printf '%s\n' 'kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid '
printf "${RESET}"

kubectl  wait --for=condition=Ready pod -l app="web-server" --timeout=240s
# being ready does not mean that port is available
sleep 20

# We keep the PID so we can stop the port-forward process later.
kubectl port-forward deployment/web-server 8000:8000 & echo $! > /tmp/pf-8000.pid 

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'We now send the first request. We add retries to ensure that the service is ready to serve requests.'
printf '%s\n' ''
printf '%s\n' 'We execute the [`test.sh`](./test.sh) to run all of these tests more easily:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' '# Test path - result in error'
printf '%s\n' 'retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path'
printf '%s\n' ''
printf '%s\n' '# Test gen'
printf '%s\n' 'retry-spinner -- curl http://localhost:8000/gen'
printf '%s\n' ''
printf '%s\n' '# Test env'
printf '%s\n' './test.sh'
printf "${RESET}"

# Test path - result in error
retry-spinner --retries 40 --wait 10 -- curl http://localhost:8000/path

# Test gen
retry-spinner -- curl http://localhost:8000/gen

# Test env
./test.sh

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '9. **Uninstall the demo**'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f manifest.cleaned.yaml'
printf '%s\n' 'kill $(cat /tmp/pf-8000.pid) || true'
printf '%s\n' 'rm /tmp/pf-8000.pid'
printf '%s\n' 'popd'
printf "${RESET}"

kubectl delete -f manifest.cleaned.yaml
kill $(cat /tmp/pf-8000.pid) || true
rm /tmp/pf-8000.pid
popd

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This demonstrates a simple, yet functional, Rust web service. Feel free to explore and modify this demo to suit your needs.'
printf "${RESET}"

