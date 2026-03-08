# `scone-td-build` Examples

The **SCONE Trust Domain Build** (`scone-td-build`) transforms cloud-native applications into confidential cloud-native applications.

Use the following examples to learn how `scone-td-build` transforms applications:

- [hello-world](./hello-world/README.md): Build a native `hello-world` program, then transform it into a confidential cloud-native program using `scone-td-build`. You can run all commands with `./scripts/hello-world.sh`.
- [configmap](./configmap/README.md): Protect `ConfigMaps` by transforming them into encrypted CAS policies.
- [web-server](./web-server/README.md): Protect `ConfigMaps` and `Secrets` by transforming them into encrypted CAS policies and mapping them as files into a web server.
- [network-policy](./network-policy/README.md): Set up SCONE-protected client/server communication over mTLS in Kubernetes. Build native images first to validate behavior, then move to a fully protected SCONE deployment using a Kubernetes `NetworkPolicy`.
- [flask-redis](./flask-redis/README.md): Deploy a SCONE-protected Flask API backed by Redis with mutual TLS in Kubernetes, including certificate generation, namespace and secret management, native smoke tests, and full integration tests for `/keys`, `/client`, `/score`, and `/memory`.

## Automation

Each example includes a generated script. These scripts suggest default values and prompt you to confirm or change them. Values are stored in each example's `Values.yaml`.

After these `Values.yaml` files are initialized, you can run all examples with:

```bash
export CONFIRM_ALL_ENVIRONMENT_VARIABLES="--value-file-only"
./scripts/run-all-scripts.sh
```
