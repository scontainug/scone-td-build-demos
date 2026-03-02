This file defines the environment variables used to configure this `configmap` example. The variables below are set with the help of `tplenv`:

1. The original cloud-native `configmap` application uses a container image.
   The URL of this image is stored in `${DEMO_IMAGE}`.
2. The URL of the generated confidential container image is stored in `${DESTINATION_IMAGE_NAME}`.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_VERSION}`.
   The current value is `7.0.0-alpha.1`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
6. The CAS name is stored in `${CAS_NAME}`.
7. If you want to use CVM mode, set `${CVM_MODE}` to `--cvm`. For SGX, leave it empty.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `--scone-enclave`.
