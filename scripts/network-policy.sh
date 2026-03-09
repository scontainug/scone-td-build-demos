#!/usr/bin/env bash

set -euo pipefail

VIOLET='\033[38;5;141m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"

printf "${VIOLET}"
printf '%s\n' '# NetworkPolicy'
printf '%s\n' ''
printf '%s\n' 'This guide explains how to build, deploy, and test the **NetworkPolicy demo** with `scone-td-build`. You will build client and server images, generate SCONE-protected images, apply Kubernetes manifests, and verify the result.'
printf '%s\n' ''
printf '%s\n' '![Network Policy Demo](../docs/network-policy.gif)'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' 'Make sure you have:'
printf '%s\n' ''
printf '%s\n' '- Docker'
printf '%s\n' '- A Kubernetes cluster with `kubectl` configured'
printf '%s\n' '- `tplenv`'
printf '%s\n' '- `scone-td-build` built locally'
printf '%s\n' '- Access to a container registry where you can push images'
printf '%s\n' ''
printf '%s\n' 'Switch to the demo directory:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'cd network-policy'
printf '%s\n' 'rm -f netshield.json || true'
printf "${RESET}"

cd network-policy
rm -f netshield.json || true

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' '## 2. Build Images'
printf '%s\n' ''
printf '%s\n' 'Initialize environment variables from `environment-variables.md` using `tplenv`:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)'
printf "${RESET}"

eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Build and push native images:'
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
printf '%s\n' '## 3. Generate SCONE Images'
printf '%s\n' ''
printf '%s\n' 'Create SCONE config files from templates, then run `scone-td-build`:'
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
printf '%s\n' '## 4. Apply Kubernetes Manifests'
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
printf '%s\n' '## 5. Test the Setup'
printf '%s\n' ''
printf '%s\n' 'Wait for pods and port-forward the server service:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="server" --timeout=300s'
printf '%s\n' 'kubectl wait --for=condition=Ready pod -l app="client" --timeout=300s'
printf '%s\n' '# A ready pod does not always mean the port is immediately available.'
printf '%s\n' 'sleep 10'
printf '%s\n' ''
printf '%s\n' 'kubectl port-forward svc/barad-dur 3000 & echo $! > /tmp/pf-3000.pid'
printf "${RESET}"

kubectl wait --for=condition=Ready pod -l app="server" --timeout=300s
kubectl wait --for=condition=Ready pod -l app="client" --timeout=300s
# A ready pod does not always mean the port is immediately available.
sleep 10

kubectl port-forward svc/barad-dur 3000 & echo $! > /tmp/pf-3000.pid

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Send requests:'
printf '%s\n' ''
printf "${RESET}"

printf "${ORANGE}"
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query'
printf '%s\n' 'curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query'
printf "${RESET}"

curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query
curl --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 5 --max-time 10 localhost:3000/db-query

printf "${VIOLET}"
printf '%s\n' ''
printf '%s\n' 'Expected result: a random 7-character password, which confirms:'
printf '%s\n' ''
printf '%s\n' '- The application is running correctly'
printf '%s\n' '- SCONE-protected images are working'
printf '%s\n' '- NetworkPolicy rules allow intended traffic'
printf '%s\n' ''
printf '%s\n' '## 6. Uninstall the Demo'
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

