#!/usr/bin/env bash
set -euo pipefail

LILAC='\033[1;35m'
RESET='\033[0m'
printf "${LILAC}"
cat <<EOF
# 🛡️ SCONE TLS Demo: Secure Client-Server Communication in Kubernetes

This example walks you through how to set up a SCONE-protected client and server
communicating over TLS in Kubernetes. You'll build native images first, then
transition to a fully protected SCONE deployment.

______________________________________________________________________

### 1. Prerequisites

- A token for accessing 'scone.cloud' images on registry.scontain.com
- A Kubernetes cluster
- The Kubernetes command line tool ('kubectl')
- Rust 'cargo' is installed ('curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh')
- You installed 'tplenv' ('cargo install tplenv') and 'retry-spinner' ('cargo install retry-spinner')

#### 2. Set up the environment

Follow the [Setup environment](https://github.com/scontain/scone) guide to install tools.

______________________________________________________________________

#### 3. Setting up the Environment Variables

EOF
printf "${RESET}"

pushd tls-demo
unset CONFIRM_ALL_ENVIRONMENT_VARIABLES

printf "${LILAC}"
cat <<EOF

The default values of several environment variables are defined in file 'Values.yaml'.
'tplenv' asks you if all defaults are ok. It then sets the environment variables:

 - '\$SERVER_IMAGE'   - name of the native server container image
 - '\$CLIENT_IMAGE'   - name of the native client container image
 - '\$IMAGE_PULL_SECRET_NAME' - the name of the pull secret (default: 'scontain')
 - '\$CAS_ADDR'       - the CAS address (e.g., 'cas.default')
 - '\$SCONE_VERSION'  - the SCONE version to use
 - '\$CVM_MODE'       - set to '--cvm' for CVM mode, leave empty for SGX
 - '\$SCONE_ENCLAVE'  - set to '--scone-enclave' for confidential K8s nodes, empty for Kata-Pods

Ensure that we ask the user to confirm or modify all environment variables:

export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"

'tplenv' will now ask the user for all environment variables described in file 'environment-variables.md':

EOF
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧱 4. Build the Native Images

This step builds native versions of the server and client images to validate
behavior before enforcing protection with SCONE.

EOF
printf "${RESET}"

pushd server
docker build -t ${SERVER_IMAGE} .
docker push ${SERVER_IMAGE}
popd

pushd client
docker build -t ${CLIENT_IMAGE} .
docker push ${CLIENT_IMAGE}
popd

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧩 Step 5: Render the Manifests

To render the manifests, we first need to define the signer key used to sign policies:

EOF
printf "${RESET}"

export SIGNER="$(scone self show-session-signing-key)"

printf "${LILAC}"
cat <<EOF

We then instantiate the manifest templates:

EOF
printf "${RESET}"

tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
tplenv --file scone.template.yaml    --create-values-file --output manifests/scone.yaml    --indent

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🔑 6. Add Docker Registry Secret to Kubernetes

We check if the pull secret already exists. If not, we ask the user for credentials:

- '\$REGISTRY'       - the registry name (default: 'registry.scontain.com')
- '\$REGISTRY_USER'  - the login name of the user pulling the container image
- '\$REGISTRY_TOKEN' - the token to pull the image (see https://sconedocs.github.io/registry/)

EOF
printf "${RESET}"

if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  echo "Secret ${IMAGE_PULL_SECRET_NAME} does not exist - creating now."
  eval $(tplenv --file registry.credentials.md --create-values-file --eval --force)
  kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
fi

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧪 7. Deploy the Native App [OPTIONAL]

EOF
printf "${RESET}"

kubectl apply -f manifests/manifest.yaml

retry-spinner -- kubectl logs job/my-tls-app -c server --follow
retry-spinner -- kubectl logs job/my-tls-app -c client --follow

kubectl delete -f manifests/manifest.yaml

printf "${LILAC}"
cat <<EOF

✅ Your containers should have completed a successful TLS handshake.

______________________________________________________________________

## 🧩 8. Prepare and Apply the SCONE Manifest

EOF
printf "${RESET}"

scone-td-build from -y manifests/scone.yaml

printf "${LILAC}"
cat <<EOF

This step:

- Generates a SCONE session
- Attaches it to your manifest
- Produces a new 'manifests/manifest.prod.sanitized.yaml' with the necessary
  information to use the created session

______________________________________________________________________

## 🚀 9. Deploy the SCONE-Protected App

EOF
printf "${RESET}"

kubectl apply -f manifests/manifest.prod.sanitized.yaml

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🔍 10. Test the Deployment

We port-forward the service and query the '/db-query' endpoint to validate
that the server returns a 7-character password:

EOF
printf "${RESET}"

kubectl port-forward svc/barad-dur 3000:3000 &
PF_PID=$!
sleep 3

RESPONSE="$(curl -s localhost:3000/db-query || true)"
kill "$PF_PID" 2>/dev/null || true

echo "Response: $RESPONSE"

if [[ "$RESPONSE" =~ ^[a-zA-Z0-9]{7}$ ]]; then
  echo "✅ TEST PASSED: 7-character password received"
else
  echo "❌ TEST FAILED: expected 7-character alphanumeric password, got: '$RESPONSE'"
  popd
  exit 1
fi

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 📜 11. View Logs

Check that SCONE-protected containers completed successfully:

EOF
printf "${RESET}"

retry-spinner -- kubectl logs job/my-tls-app -c server --follow
retry-spinner -- kubectl logs job/my-tls-app -c client --follow

printf "${LILAC}"
cat <<EOF

______________________________________________________________________

## 🧹 12. Clean Up

EOF
printf "${RESET}"

kubectl delete -f manifests/manifest.prod.sanitized.yaml

popd
