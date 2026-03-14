#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Runs a demo-style shell script generated from go-args-env-file/README.md.

Options:
  --help             Show this help message and exit.
  --non-interactive  Do not force confirmation for existing tplenv values.
USAGE
}

NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      echo "Error: This script does not accept positional arguments." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Error: This script does not accept positional arguments." >&2
  show_help >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

printf "%b" "$LILAC"
printf '%s\n' '# go-args-env-file'
printf '%s\n' ''
printf '%s\n' 'A Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. It then sleeps for 1 minute (keeping a container alive) before exiting cleanly — mirroring the behaviour of a Java reference implementation.'
printf '%s\n' ''
printf '%s\n' 'This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a Go application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Project layout'
printf '%s\n' ''
printf '%s\n' '.'
printf '%s\n' '├── main.go                    # application source'
printf '%s\n' '├── Makefile                   # build helpers'
printf '%s\n' '├── Dockerfile                 # two-stage container image'
printf '%s\n' '├── environment-variables.md   # tplenv variable definitions and defaults'
printf '%s\n' '└── manifests/'
printf '%s\n' '    ├── manifest.template.yaml     # Kubernetes Job/ConfigMap/Secret template (tplenv)'
printf '%s\n' '    ├── scone.template.yaml        # SCONE manifest template'
printf '%s\n' '    ├── manifest.yaml                  # rendered native manifest'
printf '%s\n' '    ├── scone.yaml                     # rendered SCONE manifest'
printf '%s\n' '    └── manifest.prod.sanitized.yaml   # produced by scone-td-build'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 1. Prerequisites'
printf '%s\n' ''
printf '%s\n' '- A token for accessing `scone.cloud` images on `registry.scontain.com`'
printf '%s\n' '- A Kubernetes cluster'
printf '%s\n' '- The Kubernetes command-line tool (`kubectl`)'
printf '%s\n' '- Rust `cargo` (`curl --proto '\''=https'\'' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)'
printf '%s\n' '- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)'
printf '%s\n' '- Docker (with push access to your registry)'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 2. Set Up the Environment'
printf '%s\n' ''
printf '%s\n' 'Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Change into `go-args-env-file`.
EOF
)"
pe "$(cat <<'EOF'
cd go-args-env-file
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 3. Set Up Environment Variables'
printf '%s\n' ''
printf '%s\n' 'Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:'
printf '%s\n' ''
printf '%s\n' '- `$DEMO_IMAGE` — Name of the native image to deploy'
printf '%s\n' '- `$DESTINATION_IMAGE_NAME` — Name of the confidential (SCONE-protected) image'
printf '%s\n' '- `$IMAGE_PULL_SECRET_NAME` — Pull secret name (default: `sconeapps`)'
printf '%s\n' '- `$SCONE_RUNTIME_VERSION` — SCONE version to use (for example, `6.1.0-rc.0`)'
printf '%s\n' '- `$CAS_NAMESPACE` — CAS namespace (for example, `default`)'
printf '%s\n' '- `$CAS_NAME` — CAS name (for example, `cas`)'
printf '%s\n' '- `$CVM_MODE` — Set to `--cvm` for CVM mode, otherwise leave empty for SGX'
printf '%s\n' '- `$SCONE_ENCLAVE` — In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods'
printf '%s\n' ''
printf '%s\n' 'Set `SIGNER` for policy signing:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Export the required environment variable for the next steps.
EOF
)"
pe "$(cat <<'EOF'
export SIGNER="$(scone self show-session-signing-key)"
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Load the full variable set from `environment-variables.md`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Load environment variables from the tplenv definition file.
EOF
)"
pe "$(cat <<'EOF'
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} --output /dev/null)
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 4. Build and Push the Native Docker Image'
printf '%s\n' ''
printf '%s\n' 'The Dockerfile uses a two-stage build: a `golang:1.22-alpine` builder stage compiles a fully static binary, which is then copied into a minimal `scratch` runtime image.'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Build the container image.
EOF
)"
pe "$(cat <<'EOF'
docker build -t ${DEMO_IMAGE} .
EOF
)"
pe "$(cat <<'EOF'
# Push the container image to the registry.
EOF
)"
pe "$(cat <<'EOF'
docker push ${DEMO_IMAGE}
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Alternatively, use the Makefile for a local build:'
printf '%s\n' ''
printf '%s\n' '# Native build (outputs to bin/go-args-env-file)'
printf '%s\n' 'make build'
printf '%s\n' ''
printf '%s\n' '# Cross-compile for Linux/amd64'
printf '%s\n' 'make build GOOS=linux GOARCH=amd64'
printf '%s\n' ''
printf '%s\n' '### Makefile targets'
printf '%s\n' ''
printf '%s\n' '| Target  | Description                                      |'
printf '%s\n' '|---------|--------------------------------------------------|'
printf '%s\n' '| `build` | Compile the binary into `bin/`                   |'
printf '%s\n' '| `run`   | Build then execute (pass args with `ARGS="..."`) |'
printf '%s\n' '| `tidy`  | Run `go mod tidy`                                |'
printf '%s\n' '| `fmt`   | Run `go fmt ./...`                               |'
printf '%s\n' '| `vet`   | Run `go vet ./...`                               |'
printf '%s\n' '| `test`  | Run `go test ./...`                              |'
printf '%s\n' '| `clean` | Remove the `bin/` directory                      |'
printf '%s\n' '| `help`  | Print usage summary                              |'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 5. Render the Manifests'
printf '%s\n' ''
printf '%s\n' '`tplenv` substitutes environment variables into the template files and writes the final manifests:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file manifests/manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
EOF
)"
pe "$(cat <<'EOF'
# Render the template with the selected values.
EOF
)"
pe "$(cat <<'EOF'
tplenv --file manifests/scone.template.yaml    --create-values-file --output manifests/scone.yaml    --indent
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Before applying, confirm that image values were substituted correctly.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 6. Add a Docker Registry Secret'
printf '%s\n' ''
printf '%s\n' 'If you need a pull secret for native and confidential images, create it when missing:'
printf '%s\n' ''
printf '%s\n' '- `$REGISTRY` — Registry hostname (default: `registry.scontain.com`)'
printf '%s\n' '- `$REGISTRY_USER` — Registry login name'
printf '%s\n' '- `$REGISTRY_TOKEN` — Registry pull token (see <https://sconedocs.github.io/registry/>)'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Check whether the pull secret already exists.
EOF
)"
pe "$(cat <<'EOF'
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
EOF
)"
pe "$(cat <<'EOF'
  # Print a status message.
EOF
)"
pe "$(cat <<'EOF'
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
EOF
)"
pe "$(cat <<'EOF'
else
EOF
)"
pe "$(cat <<'EOF'
  # Create the Docker registry pull secret.
EOF
)"
pe "$(cat <<'EOF'
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
EOF
)"
pe "$(cat <<'EOF'
fi
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 7. Deploy the Native App'
printf '%s\n' ''
printf '%s\n' 'Apply the manifest, wait for the job to complete, and inspect its logs to confirm the app prints arguments, environment variables, and the contents of the ConfigMap and Secret files:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifests/manifest.yaml
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=complete job/go-args-env-file --timeout=240s
EOF
)"
pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/go-args-env-file
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'Your container should print the command-line args, all environment variables, the contents of `/config/configs.yaml`, and `/config/secrets`.'
printf '%s\n' ''
printf '%s\n' 'Clean up the native deployment before moving on:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f manifests/manifest.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'The manifest mounts:'
printf '%s\n' '- `ConfigMap/app-config` → `/config/configs.yaml`'
printf '%s\n' '- `Secret/app-secrets`  → `/config/secrets`'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 8. Prepare and Apply the SCONE Manifest'
printf '%s\n' ''
printf '%s\n' 'Build the confidential image and generate the SCONE session from `manifests/scone.yaml`:'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Generate the confidential image and sanitized manifest from the SCONE configuration.
EOF
)"
pe "$(cat <<'EOF'
scone-td-build from -y manifests/scone.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' 'This command:'
printf '%s\n' ''
printf '%s\n' '- Generates a SCONE session'
printf '%s\n' '- Attaches the session to your manifest'
printf '%s\n' '- Produces `manifests/manifest.prod.sanitized.yaml`'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 9. Deploy the SCONE-Protected App'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Apply the Kubernetes manifest.
EOF
)"
pe "$(cat <<'EOF'
kubectl apply -f manifests/manifest.prod.sanitized.yaml
EOF
)"
pe "$(cat <<'EOF'
# Wait for the Kubernetes resource to reach the expected state.
EOF
)"
pe "$(cat <<'EOF'
kubectl wait --for=condition=complete job/go-args-env-file --timeout=300s
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 10. View Logs'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Show logs from the Kubernetes workload.
EOF
)"
pe "$(cat <<'EOF'
kubectl logs job/go-args-env-file
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## 11. Clean Up'
printf '%s\n' ''
printf "%b" "$RESET"

pe "$(cat <<'EOF'
# Delete the Kubernetes resource if it exists.
EOF
)"
pe "$(cat <<'EOF'
kubectl delete -f manifests/manifest.prod.sanitized.yaml
EOF
)"

printf "%b" "$LILAC"
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## What the app does'
printf '%s\n' ''
printf '%s\n' '1. Prints all **command-line arguments** passed to the binary.'
printf '%s\n' '2. Dumps all **environment variables** in the process environment.'
printf '%s\n' '3. Reads and prints two files:'
printf '%s\n' '   - `/config/configs.yaml` — general configuration (mounted from a `ConfigMap`)'
printf '%s\n' '   - `/config/secrets` — secret values (mounted from a Kubernetes `Secret`)'
printf '%s\n' '4. **Sleeps for about 10 seconds**, then exits. This is expected, so the Kubernetes workload is modeled as a `Job` rather than a long-running `Deployment`.'
printf '%s\n' ''
printf '%s\n' '---'
printf '%s\n' ''
printf '%s\n' '## Signal handling'
printf '%s\n' ''
printf '%s\n' 'The process listens for `SIGINT` and `SIGTERM`. On receipt it prints the signal name to **stderr** and exits immediately, making it suitable for graceful shutdown in containerised environments.'
printf "%b" "$RESET"

