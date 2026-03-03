# `scone-td-build` Examples

The **SCONE Trust Domain Build** (`scone-td-build`) transforms cloud-native applications into confidential cloud-native applications.

Check out the following examples to learn more about how `scone-td-build` transforms applications:

- [hello-world](./hello-world/README.md): First, build a native `hello-world` program. Then, transform it into a confidential cloud-native program using `scone-td-build`. You can run all commands using `./scripts/hello-world.sh`.

- [configmap](./configmap/README.md): Next, we show how to protect `ConfigMaps` by transforming them into encrypted CAS policies.

- [web-server](./web-server/README.md): Finally, we show how to protect `ConfigMaps` and `Secrets` by transforming them into encrypted CAS policies and mapping them as files into a web server.

- [network-policy](./network-policy/README.md): Shows how to set up a SCONE-protected client and server communicating over TLS in Kubernetes. Builds native images first to validate behavior, then transitions to a fully protected SCONE deployment. The client queries the server's `/db-query` endpoint and validates the response.

- [flask-redis](./flask-redis/README.md): Shows how to deploy a SCONE-protected Flask API backed by Redis with mutual TLS in Kubernetes. Covers certificate generation, namespace and secret management, native smoke testing, and full integration testing of the `/keys`, `/client`, `/score`, and `/memory` endpoints against the SCONE-protected deployment.
