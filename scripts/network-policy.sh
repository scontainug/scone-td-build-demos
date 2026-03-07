#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# NetworkPolicy'
printf '%s\n' ''
printf '%s\n' 'This guide shows how to build, deploy, and test the **NetworkPolicy demo** using `scone-td-build`. You will build client and server images, generate SCONE-protected images, apply the Kubernetes manifests, and verify that everything works as expected.'
printf '%s\n' ''
printf '%s\n' '![Network Policy Demo](../docs/network-policy.gif)'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🧱 Normal Setup'
printf '%s\n' ''
printf '%s\n' 'Make sure you have the following tools installed and configured:'
printf '%s\n' ''
printf '%s\n' '- Docker'
printf '%s\n' '- Kubernetes cluster (with `kubectl` configured)'
printf '%s\n' '- `scone-td-build` built locally'
printf '%s\n' '- Access to a container registry where you can push images'
printf '%s\n' ''
printf '%s\n' 'Navigate to the NetworkPolicy demo directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cd network-policy'
printf "${RESET}"

cd network-policy

printf "${VIOLET}"
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🐳 Build Images'
printf '%s\n' ''
printf '%s\n' 'First, define the names of the Docker images that will be used for the demo. Hence, `tplenv` will now ask for all environment variables described in `environment-variables.md`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output  /dev/null )

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' ''
printf '%s\n' '### Build and push the base images'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'docker build -t $SERVER_IMAGE "server/"'
printf '%s\n' 'docker build -t $CLIENT_IMAGE "client/"'
printf '%s\n' ''
printf '%s\n' 'docker push $SERVER_IMAGE'
printf '%s\n' 'docker push $CLIENT_IMAGE'
printf "${RESET}"

docker build -t $SERVER_IMAGE "server/"
docker build -t $CLIENT_IMAGE "client/"

docker push $SERVER_IMAGE
docker push $CLIENT_IMAGE

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '### Generate SCONE images'
printf '%s\n' ''
printf '%s\n' 'Create the SCONE configuration from the template and apply it using `scone-td-build`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"'
printf '%s\n' 'tplenv --file "./scone.template.yaml" --output "./scone.yaml"'
printf '%s\n' 'scone-td-build from -y ./scone.yaml'
printf "${RESET}"

tplenv --file "./manifest.template.yaml" --output "./manifest.yaml"
tplenv --file "./scone.template.yaml" --output "./scone.yaml"
scone-td-build from -y ./scone.yaml

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'This will generate SCONE-protected variants of both images.'
printf '%s\n' ''
printf '%s\n' 'Push the generated SCONE images:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'docker push $SERVER_IMAGE-scone'
printf '%s\n' 'docker push $CLIENT_IMAGE-scone'
printf "${RESET}"

docker push $SERVER_IMAGE-scone
docker push $CLIENT_IMAGE-scone

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## 🚀 Apply Kubernetes Manifests'
printf '%s\n' ''
printf '%s\n' 'Deploy the application and NetworkPolicy configuration to the cluster:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl apply -f "manifest.prod.sanitized.yaml"'
printf "${RESET}"

kubectl apply -f "manifest.prod.sanitized.yaml"

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Wait until all pods are running before continuing.'
printf '%s\n' ''
printf '%s\n' '______________________________________________________________________'
printf '%s\n' ''
printf '%s\n' '## ✅ Test the Setup'
printf '%s\n' ''
printf '%s\n' 'Forward the server service port to your local machine:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl  wait --for=condition=Ready pod -l app="server" --timeout=300s'
printf '%s\n' 'kubectl  wait --for=condition=Ready pod -l app="client" --timeout=300s'
printf '%s\n' '# being ready does not mean that port is available'
printf '%s\n' 'sleep 10'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward svc/barad-dur 3000 &  echo $! > /tmp/pf-3000.pid'
printf "${RESET}"

kubectl  wait --for=condition=Ready pod -l app="server" --timeout=300s
kubectl  wait --for=condition=Ready pod -l app="client" --timeout=300s
# being ready does not mean that port is available
sleep 10

kubectl port-forward svc/barad-dur 3000 &  echo $! > /tmp/pf-3000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send a request to the server:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query '
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query '
printf "${RESET}"

curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query 
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query 

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '### Expected Result'
printf '%s\n' ''
printf '%s\n' 'The request should return a **random 7-character password**, confirming that:'
printf '%s\n' ''
printf '%s\n' '- The application is running correctly'
printf '%s\n' '- The SCONE-protected images are working'
printf '%s\n' '- NetworkPolicy rules allow the intended traffic'
printf '%s\n' ''
printf '%s\n' '9. **Uninstall the demo**'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl delete -f manifest.prod.sanitized.yaml'
printf '%s\n' 'kill $(cat /tmp/pf-3000.pid) || true'
printf '%s\n' 'rm /tmp/pf-3000.pid'
printf '%s\n' 'cd -'
printf "${RESET}"

kubectl delete -f manifest.prod.sanitized.yaml
kill $(cat /tmp/pf-3000.pid) || true
rm /tmp/pf-3000.pid
cd -

