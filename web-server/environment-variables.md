This file defines the environment variables that we use to configure this `web-server` example. This includes the following environment variables - which are set with the help of `tplenv`:

1. The original cloud-native `web-server` application uses a container image.
   The URL of this container image is stored in environment variable ${IMAGE_NAME}
2. The URL of the generated confidential container image is stored 
   in environment variable ${DESTINATION_IMAGE_NAME}
3. The name of the pull secret for the native and the confidential 
   container images is stored in environment variable ${IMAGE_PULL_SECRET_NAME}
4. The SCONE version is stored in environment variable ${SCONE_VERSION}
   Right now this is 7.0.0-alpha.1: 
5. The CAS that we use runs in Kubernetes namespace: ${CAS_NAMESPACE}
6. The name of the CAS is stored in environment variable ${CAS_NAME}
7. If you want to have CVM mode, set to --cvm. For SGX, please leave empty: ${CVM_MODE}
8. In CVM mode, you can run using confidential Kubernetes nodes or Kata-Pods. 
   Our recommendation is to use confidential node and set ${SCONE_ENCLAVE} to "--scone-enclave" 
