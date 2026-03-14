# `scone-td-build` Examples

The **SCONE Trust Domain Build** (`scone-td-build`) transforms cloud-native applications into confidential cloud-native applications. 

Our general objectives are as follows that no user with access to the cluster (i.e., not even the root user) can modify:

- the **code** or the **configuration** of an application
- the data of the application

Moreover, we want to prevent any user with access to the cluster to

- read configuration files - which might contain source code and keys,
- read files that store application data.

Note that this approach is independent if we run on computers with Intel TDX, AMD SEV SNP, or Intel SGX.


Use the following examples to learn how `scone-td-build` transforms applications:

- [hello-world](./hello-world/README.md): Build a native `hello-world` program, then transform it into a confidential cloud-native program using `scone-td-build`. You can run all commands with `./scripts/hello-world.sh`.
- [configmap](./configmap/README.md): Protect `ConfigMaps` by transforming them into encrypted CAS policies.
- [web-server](./web-server/README.md): Protect `ConfigMaps` and `Secrets` by transforming them into encrypted CAS policies and mapping them as files into a web server.
- [network-policy](./network-policy/README.md): Set up SCONE-protected client/server communication over mTLS in Kubernetes. Build native images first to validate behavior, then move to a fully protected SCONE deployment using a Kubernetes `NetworkPolicy`.
- [flask-redis](./flask-redis/README.md): Deploy a SCONE-protected Flask API backed by Redis with mutual TLS in Kubernetes, including certificate generation, namespace and secret management, native smoke tests, and full integration tests for `/keys`, `/client`, `/score`, and `/memory`.
- [go-args-env-file](./go-args-env-file/README.md): Deploy a SCONE-protected Go utility that prints command-line arguments, environment variables, and reads two config files from `/config/`.

## Background

- We have some background sections:

- [Container Registry Basics](ContainerRegistryBasics.md): Some basic background related to repositories, pull secrets, etc.
- [Create Own Repository](CreateOwnRepository.md): Explains how to set up a  repositoy on GitHub.

## Automation

Each example includes a generated script. These scripts suggest default values and prompt you to confirm or change them. Values are stored in each example's `Values.yaml`.

After these `Values.yaml` files are initialized, you can run all examples with:

```bash
# Run the generated scripts for all demos.
./scripts/run-all-scripts.sh
```

## Cleanup

Note that registry tokens, registry user IDs, and public signer keys are stored in the value files. To remove this data, execute

```bash
./scripts/remove-values-secrets.sh
```
