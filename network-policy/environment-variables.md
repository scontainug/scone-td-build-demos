This file defines the environment variables used to configure the `network-policy` example. The variables below are collected with `tplenv`:

1. The client image is pushed to `${CLIENT_IMAGE}`.
   Use a full image name, including the registry, for example `docker.io/youruser/demo-client`.
   You should use your own image name because you likely do not have push access to the example repository.
2. The server image is pushed to `${SERVER_IMAGE}`.
   Use a full image name, including the registry, for example `docker.io/youruser/demo-server`.
   You should use your own image name because you likely do not have push access to the example repository.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The recommended value is `6.1.0-rc.0`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
   The templates resolve `${CAS_NAME}.${CAS_NAMESPACE}` to the CAS endpoint, so for SCONE's public CAS at `scone-cas.cf` set `CAS_NAMESPACE=cf`.
6. The CAS name is stored in `${CAS_NAME}`.
   For SCONE's public CAS, set `CAS_NAME=scone-cas`.
7. If you want to use CVM mode, set `${CVM_MODE}` to `true`. For SGX, set to `false`.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. The manifests are stored in `${SCRIPT_DIR}`
10. Set the local signer key in `${SIGNER}`.
    This should already be set to the output of `scone self show-session-signing-key`.
11. The Kubernetes namespace where the demo manifests are deployed is stored in `${NAMESPACE}`.
    The default value is `default`.
