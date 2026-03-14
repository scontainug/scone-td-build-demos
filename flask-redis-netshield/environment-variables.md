This file defines the environment variables used to configure the `flask-redis-netshield` example. The variables below are collected with `tplenv`:

1. The URL of the Flask API image is stored in `${IMAGE_NAME}`.
2. The Kubernetes namespace used for all resources is stored in `${NAMESPACE}`.
3. The image pull secret name used by Kubernetes deployments is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_RUNTIME_VERSION}`.
   The current value is `6.1.0-rc.0`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
6. The CAS name is stored in `${CAS_NAME}`.
7. If you want to use CVM mode, set `${CVM_MODE}` to `true`. For SGX, set to `false`.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. Set the local signer key in `${SIGNER}`.
   This should already be set to the output of `scone self show-session-signing-key`.
