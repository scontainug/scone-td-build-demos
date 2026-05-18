# `scone-td-build` Examples

The **SCONE Trust Domain Build** (`scone-td-build`) transforms cloud-native applications into confidential cloud-native applications.

Our overall goal is that no user with access to the cluster, not even the root user, can modify:

- the **code** or the **configuration** of an application
- the data of the application

Beyond **integrity**, we also protect **confidentiality** so that no user with access to the cluster can:

- read configuration files, which might contain source code and keys
- read files used to store application data

This approach works independently of whether we run on machines with Intel TDX, AMD SEV-SNP, or Intel SGX. We guarantee this property even if an adversary has gained access to the CVM itself.

## Examples

Use the following examples to learn how `scone-td-build` transforms applications:

- [hello-world](./hello-world/README.md): Build a native `hello-world` program, then transform it into a confidential cloud-native program using `scone-td-build`. You can run all commands with `./scripts/hello-world.sh`. The focus of this exaple is on how to protect the integrity of the program code.
- [configmap](./configmap/README.md): Protect `ConfigMaps` by transforming them into encrypted CAS policies. This shows how to protect `ConfigMaps`.
- [web-server](./web-server/README.md): Protect `ConfigMaps` and `Secrets` by transforming them into encrypted CAS policies and mapping them as files into a web server. This example uses a `Deployment` instead of a `ConfigMap`.
- [network-policy](./network-policy/README.md): Set up SCONE-protected client/server communication over mTLS in Kubernetes. Build native images first to validate behavior, then move to a fully protected SCONE deployment using a Kubernetes `NetworkPolicy`.
- [flask-redis](./flask-redis/README.md): Deploy a SCONE-protected Flask API backed by Redis with mutual TLS in Kubernetes, including (manual) certificate generation, namespace and secret management, native smoke tests, and full integration tests for `/keys`, `/client`, `/score`, and `/memory`.
- [flask-redis-netshield](./flask-redis-netshield/README.md): Extends `flask-redis` by adding a network policy to encrypt network traffic between `flask` and `redis` services.
- [go-args-env-file](./go-args-env-file/README.md): Deploy a SCONE-protected Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`. We use a slightly enhanced Go runtime which uses a libc to issue system calls.
- [java-args-env-file](./java-args-env-file/README.md): Deploy a Java utility that prints command-line arguments, environment variables, and reads two config files from `/config/`.
- [software-updates](./software-updates/README.md): Perform a **software update** of a confidential Python application. `API_PASSWORD` is encrypted into the CAS session (never visible in any Kubernetes object) and preserved across the rolling update from Version 1 to Version 2.

## Background

- [Kubernetes Basics](Kubernetes_basic_concepts.md): Some basic Kubernetes concepts that we use in our examples.
- [Container Registry Basics](ContainerRegistryBasics.md): Some basic background related to repositories, pull secrets, etc.
- [Create Own Repository](CreateOwnRepository.md): In the examples, we create new container images and push them to repositories. This document explains how to set up a repository on GitHub.

## Automation and Testing

Each example includes a generated script. These scripts suggest default values and prompt you to confirm or change them. Values are stored in each example's `Values.yaml`.

Once these `Values.yaml` files are initialized, you can run all examples with:

```bash
# Run the generated scripts for all demos.
./scripts/run-all-scripts.sh
```

For GitHub Actions on a self-hosted runner, see [GitHubActionsSelfHosted.md](GitHubActionsSelfHosted.md).

## Cleanup

Note that registry tokens, registry user IDs, and public signer keys are stored in the value files. To remove this data, run:

```bash
./scripts/remove-values-secrets.sh
```
