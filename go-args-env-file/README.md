# go-args-env-file

A Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. It then sleeps for 1 minute (keeping a container alive) before exiting cleanly — mirroring the behaviour of a Java reference implementation.

This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a Go application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.

---

## Project layout

```
.
├── main.go                    # application source
├── Makefile                   # build helpers
├── Dockerfile                 # two-stage container image
├── environment-variables.md   # tplenv variable definitions and defaults
└── manifests/
    ├── manifest.template.yaml     # Kubernetes Job/ConfigMap/Secret template (tplenv)
    ├── scone.template.yaml        # SCONE manifest template
    ├── manifest.yaml                  # rendered native manifest
    ├── scone.yaml                     # rendered SCONE manifest
    └── manifest.prod.sanitized.yaml   # produced by scone-td-build
```

---

## 1. Prerequisites

- A token for accessing `scone.cloud` images on `registry.scontain.com`
- A Kubernetes cluster
- The Kubernetes command-line tool (`kubectl`)
- Rust `cargo` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- `tplenv` (`cargo install tplenv`) and `retry-spinner` (`cargo install retry-spinner`)
- Docker (with push access to your registry)

---

## 2. Set Up the Environment

Follow the [Setup environment](https://github.com/scontain/scone) guide. The easiest option is usually the Kubernetes-based setup in [k8s.md](https://github.com/scontain/scone/blob/main/k8s.md).

```bash
# Change into `go-args-env-file`.
cd go-args-env-file
```

---

## 3. Set Up Environment Variables

Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:

- `$DEMO_IMAGE` — Name of the native image to deploy
- `$DESTINATION_IMAGE_NAME` — Name of the confidential (SCONE-protected) image
- `$IMAGE_PULL_SECRET_NAME` — Pull secret name (default: `sconeapps`)
- `$SCONE_RUNTIME_VERSION` — SCONE version to use (for example, `6.1.0-rc.0`)
- `$CAS_NAMESPACE` — CAS namespace (for example, `default`)
- `$CAS_NAME` — CAS name (for example, `cas`)
- `$CVM_MODE` — Set to `--cvm` for CVM mode, otherwise leave empty for SGX
- `$SCONE_ENCLAVE` — In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods

Set `SIGNER` for policy signing:

```bash
# Export the required environment variable for the next steps.
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
# Load environment variables from the tplenv definition file.
eval $(tplenv --file environment-variables.md --create-values-file --context --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES} --output /dev/null)
```

---

## 4. Build and Push the Native Docker Image

The Dockerfile uses a two-stage build: a `golang:1.22-alpine` builder stage compiles a fully static binary, which is then copied into a minimal `scratch` runtime image.

```bash
# Build the container image.
docker build -t ${DEMO_IMAGE} .
# Push the container image to the registry.
docker push ${DEMO_IMAGE}
```

Alternatively, use the Makefile for a local build:

```
# Native build (outputs to bin/go-args-env-file)
make build

# Cross-compile for Linux/amd64
make build GOOS=linux GOARCH=amd64
```

### Makefile targets

| Target  | Description                                      |
|---------|--------------------------------------------------|
| `build` | Compile the binary into `bin/`                   |
| `run`   | Build then execute (pass args with `ARGS="..."`) |
| `tidy`  | Run `go mod tidy`                                |
| `fmt`   | Run `go fmt ./...`                               |
| `vet`   | Run `go vet ./...`                               |
| `test`  | Run `go test ./...`                              |
| `clean` | Remove the `bin/` directory                      |
| `help`  | Print usage summary                              |

---

## 5. Render the Manifests

`tplenv` substitutes environment variables into the template files and writes the final manifests:

```bash
# Render the template with the selected values.
tplenv --file manifests/manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
# Render the template with the selected values.
tplenv --file manifests/scone.template.yaml    --create-values-file --output manifests/scone.yaml    --indent
```

Before applying, confirm that image values were substituted correctly.

---

## 6. Add a Docker Registry Secret

If you need a pull secret for native and confidential images, create it when missing:

- `$REGISTRY` — Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` — Registry login name
- `$REGISTRY_TOKEN` — Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
# Check whether the pull secret already exists.
if kubectl get secret "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  # Print a status message.
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  # Create the Docker registry pull secret.
  kubectl create secret docker-registry "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
fi
```

---

## 7. Deploy the Native App

Apply the manifest and follow the pod logs to confirm the app prints arguments, environment variables, and the contents of the ConfigMap and Secret files:

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifests/manifest.yaml
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner --retries 10 --wait 2 -- kubectl logs deployment/go-args-env-file
```

Your container should print the command-line args, all environment variables, the contents of `/config/configs.yaml`, and `/config/secrets`.

Clean up the native deployment before moving on:

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f manifests/manifest.yaml
```

The manifest mounts:
- `ConfigMap/app-config` → `/config/configs.yaml`
- `Secret/app-secrets`  → `/config/secrets`

---

## 8. Prepare and Apply the SCONE Manifest

Build the confidential image and generate the SCONE session from `manifests/scone.yaml`:

```bash
# Generate the confidential image and sanitized manifest from the SCONE configuration.
scone-td-build from -y manifests/scone.yaml
```

This command:

- Generates a SCONE session
- Attaches the session to your manifest
- Produces `manifests/manifest.prod.sanitized.yaml`

---

## 9. Deploy the SCONE-Protected App

```bash
# Apply the Kubernetes manifest.
kubectl apply -f manifests/manifest.prod.sanitized.yaml
```

---

## 10. View Logs

```bash
# Retry the wrapped command until it succeeds or reaches the retry limit.
retry-spinner -- kubectl logs deployment/go-args-env-file --follow
```

---

## 11. Clean Up

```bash
# Delete the Kubernetes resource if it exists.
kubectl delete -f manifests/manifest.prod.sanitized.yaml
```

---

## What the app does

1. Prints all **command-line arguments** passed to the binary.
2. Dumps all **environment variables** in the process environment.
3. Reads and prints two files:
   - `/config/configs.yaml` — general configuration (mounted from a `ConfigMap`)
   - `/config/secrets` — secret values (mounted from a Kubernetes `Secret`)
4. **Sleeps for 1 minute**, then exits. Handles `SIGINT` / `SIGTERM` gracefully (reports the signal to stderr and exits early).

---

## Signal handling

The process listens for `SIGINT` and `SIGTERM`. On receipt it prints the signal name to **stderr** and exits immediately, making it suitable for graceful shutdown in containerised environments.
