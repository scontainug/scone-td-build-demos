This file defines the environment variables used to configure the TDX workshop. The variables below are set with the help of `tplenv`:

1. The path to the Azure credentials JSON file is stored in `${AZURE_CREDENTIALS}`.
   This file is created via `az ad sp create-for-rbac --sdk-auth`.
2. The path to the CVM config JSON file is stored in `${CVM_CONFIG}`.
   This file references the custom CVM gallery image with the `scone_enclave` kernel driver.
3. The path to the kubeconfig file for the TDX cluster is stored in `${KUBECONFIG_PATH}`.
4. The number of cluster nodes is stored in `${NODE_COUNT}`.
5. The memory (GB) per node is stored in `${MEMORY}`.
6. The number of virtual cores per node is stored in `${VCORES}`.
7. The Azure resource group is stored in `${RESOURCE_GROUP}`.
   If left empty, one will be auto-generated.
8. The SCONE runtime version used by demos is stored in `${SCONE_VERSION}`.
   The current value is `6.1.0-rc.0`.
9. The SCONE SGX plugin version to install is stored in `${SGX_PLUGIN_VERSION}`.
   The current value is `7.0.0-alpha.1`.
10. The cert-manager version compatible with the cluster's Kubernetes release is stored in `${CERT_MANAGER_VERSION}`.
    The current value is `v1.17.1`.
11. The Intel DCAP API key (32 hex characters) is stored in `${DCAP_KEY}`.
12. The SCONE container registry is stored in `${REGISTRY}`.
13. The registry username is stored in `${REGISTRY_USER}`.
14. The registry access token is stored in `${REGISTRY_TOKEN}`.
15. The registry email is stored in `${REGISTRY_EMAIL}`.
16. The CAS name is stored in `${CAS_NAME}`.
    For the public CAS, this is `scone-cas`.
17. The CAS namespace is stored in `${CAS_NAMESPACE}`.
    For the public CAS, this is `cf` (giving hostname `scone-cas.cf`).
