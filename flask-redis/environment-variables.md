This file defines the environment variables used to configure the `flask-redis` example. The variables below are set with the help of `tplenv`:

1. The URL of the Flask API container image is stored in `${IMAGE_NAME}`.
2. The Kubernetes namespace used for all resources is stored in `${NAMESPACE}`.
3. The image pull secret name used by Kubernetes deployments is stored in `${IMAGE_PULL_SECRET_NAME}`.
4. The SCONE version is stored in `${SCONE_VERSION}`.
   The current value is `7.0.0-alpha.1`.
