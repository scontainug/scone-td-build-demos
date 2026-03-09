1. We push the client network policy image to ${CLIENT_IMAGE}.
   For example, we use the following image name: 
        www.scontain.com/workshop/network-policy:client
   You need to use a different image name since you should not have 
   push rights to this repo. These should be full image names, including
   the registry. For example: `docker.io/youruser/demo-client`.
2. We push the client network policy image to ${SERVER_IMAGE}.
   For example, we use the following image name: 
        www.scontain.com/workshop/network-policy:server
   You need to use a different image name since you should 
   not have push rights to this repo.
3. The name of the pull secret for both the native and confidential container images is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_VERSION}`.
   The recommended value is `6.1.0-rc.0`.
5. The CAS runs in Kubernetes namespace `${CAS_NAMESPACE}`.
6. The CAS name is stored in `${CAS_NAME}`.
7. If you want to use CVM mode, set `${CVM_MODE}` to `true`. For SGX, set to `false`.
8. In CVM mode, you can run on confidential Kubernetes nodes or Kata Pods.
   We recommend using confidential nodes and setting `${SCONE_ENCLAVE}` to `true`.
9. The manifests are stored in `${SCRIPT_DIR}`