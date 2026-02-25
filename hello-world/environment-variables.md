This file defines the environment variables that we use to configure this hello world example. This includes the following environment variables - which are set with the help of `tplenv`:

1. Original native conatainer image is stored: ${IMAGE_NAME}
2. Destination of the confidential container image: ${DESTINATION_IMAGE_NAME}
3. The name of the pull secret: ${IMAGE_PULL_SECRET_NAME}
4. The SCONE version to use: ${SCONE_VERSION}
5. The CAS namespace to use: ${CAS_NAMESPACE}
6. The CAS name to use: ${CAS_NAME}
7. If you want to have CVM mode, set to --cvm. For SGX, leave empty: ${CVM_MODE}
8. In CVM mode, you can run using the nodes or Kata-Pods. Mainly, set to --scone-enclave: ${SCONE_ENCLAVE}
