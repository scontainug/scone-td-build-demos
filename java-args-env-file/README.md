# java-args-env-file (Java)

A Java utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. It then sleeps for 1 hour (keeping a container alive) before exiting cleanly.

This example shows how to manage and access configuration data in Kubernetes with a `ConfigMap` and a SCONE-enabled Java application. You start with a plain (unencrypted) deployment and then move to a fully protected SCONE deployment.

---

## Project layout

```
.
├── Main.java                  # application source
├── Dockerfile                 # two-stage image: JDK builder → JRE runtime
├── environment-variables.md   # tplenv variable definitions and defaults
└── manifests/
    ├── manifest.yaml                 # rendered native manifest
    ├── scone.yaml                      # rendered SCONE manifest
    ├── manifest.template.yaml          # Kubernetes Job + ConfigMap + Secret template (tplenv)
    ├── scone.template.yaml             # SCONE manifest template
    └── manifest.prod.sanitized.yaml    # produced by scone-td-build
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

---

## 3. Set Up Environment Variables

Default values are stored in `Values.yaml`. `tplenv` asks whether to keep the defaults and then sets these variables:

- `$DEMO_IMAGE` — Name of the native image to deploy
- `$DESTINATION_IMAGE_NAME` — Name of the confidential (SCONE-protected) image
- `$IMAGE_PULL_SECRET_NAME` — Pull secret name (default: `sconeapps`)
- `$SCONE_VERSION` — SCONE version to use (for example, `6.1.0-rc.0`)
- `$CAS_NAMESPACE` — CAS namespace (for example, `default`)
- `$CAS_NAME` — CAS name (for example, `cas`)
- `$CVM_MODE` — Set to `--cvm` for CVM mode, otherwise leave empty for SGX
- `$SCONE_ENCLAVE` — In CVM mode, set to `--scone-enclave` for confidential nodes, or leave empty for Kata Pods
- `$NAMESPACE` — namespace name (for example, `java demo`)

Set `SIGNER` for policy signing:

```bash
export SIGNER="$(scone self show-session-signing-key)"
```

Load the full variable set from `environment-variables.md`:

```bash
eval $(tplenv --file environment-variables.md --create-values-file --context --eval --force --output /dev/null)
```

---

## 4. Build and Push the Native Docker Image

The Dockerfile uses a two-stage build: an `eclipse-temurin:21-jdk-alpine` builder stage compiles `Main.java`, and the resulting `.class` file is copied into a minimal `eclipse-temurin:21-jre-alpine` runtime image.

```bash
docker build -t ${DEMO_IMAGE} .
docker push ${DEMO_IMAGE}
```

---

## 5. Render the Manifests

`tplenv` substitutes environment variables into the template files and writes the final manifests:

```bash
tplenv --file manifest.template.yaml --create-values-file --output manifests/manifest.yaml --indent
tplenv --file scone.template.yaml    --create-values-file --output manifests/scone.yaml    --indent
```

Before applying, confirm that image values were substituted correctly.

---

## 6. Add a Docker Registry Secret

If you need a pull secret for native and confidential images, create it when missing:

- `$REGISTRY` — Registry hostname (default: `registry.scontain.com`)
- `$REGISTRY_USER` — Registry login name
- `$REGISTRY_TOKEN` — Registry pull token (see <https://sconedocs.github.io/registry/>)

```bash
if kubectl get secret -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret ${IMAGE_PULL_SECRET_NAME} already exists"
else
  kubectl create secret docker-registry -n "${NAMESPACE}" "${IMAGE_PULL_SECRET_NAME}" \
    --docker-server=$REGISTRY \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN
fi
```

---

## 7. Deploy the Native App

Apply the manifest and follow the pod logs to confirm the app prints arguments, environment variables, and the contents of the ConfigMap and Secret files:

```bash
kubectl apply -f manifests/manifest.yaml
retry-spinner --retries 10 --wait 2 -- kubectl logs deployment/java-args-env-file --follow
```

Your container should print the command-line args, all environment variables, the contents of `/config/configs.yaml`, and `/config/secrets`.

Clean up the native deployment before moving on:

```bash
kubectl delete -f manifests/manifest.yaml
```

The manifest mounts:
- `ConfigMap/app-config` → `/config/configs.yaml`
- `Secret/app-secrets`  → `/config/secrets`

---

## 8. Prepare and Apply the SCONE Manifest

Build the confidential image and generate the SCONE session from `manifests/scone.yaml`:

```bash
scone-td-build from -y manifests/scone.yaml
```

This command:

- Generates a SCONE session
- Attaches the session to your manifest
- Produces `manifests/manifest.prod.sanitized.yaml`

---

## 9. Deploy the SCONE-Protected App

```bash
kubectl apply -f manifests/manifest.prod.sanitized.yaml
```

---

## 10. View Logs

```bash
retry-spinner -- kubectl logs deployment/java-args-env-file --follow
```

---

## 11. Clean Up

```bash
kubectl delete -f manifests/manifest.prod.sanitized.yaml
```

---

## What the app does

1. Prints all **command-line arguments** passed to `main(String[] args)`.
2. Dumps all **environment variables** via `System.getenv()`.
3. Reads and prints two files using `Files.lines()`:
   - `/config/configs.yaml` — general configuration (mounted from a `ConfigMap`)
   - `/config/secrets` — secret values (mounted from a Kubernetes `Secret`)
4. **Sleeps for 1 hour**, then exits. Handles `InterruptedException` gracefully (reports to stderr and exits early).

---

## Signal handling

The JVM catches `InterruptedException` during `Thread.sleep()`. On interruption it prints the exception message to **stderr** and exits, making it suitable for graceful shutdown in containerised environments.

