This file defines the environment variables used by the automated GitHub Container Registry workflow:

1. `${GITHUB_OWNER}` is the GitHub user or organization that will own the repository and container package.
   By default, the script fills this from the currently authenticated `gh` account.
2. `${REPOSITORY_NAME}` is the GitHub repository name to create or update.
   By default, the script uses the basename of `${SOURCE_DIR}`.
3. `${REPOSITORY_VISIBILITY}` controls the GitHub repository visibility.
   Allowed values are `private`, `public`, or `internal`.
4. `${SOURCE_DIR}` is the local Docker build context directory.
   The script defaults this to the current working directory from which the script is invoked.
5. `${IMAGE_NAME}` is the GitHub Container Registry package name.
   By default, the script uses the repository name lowercased.
6. `${IMAGE_TAG}` is the image tag to build and push.
   The default value is `latest`.
7. `${PACKAGE_VISIBILITY}` controls the package visibility in GHCR after the first push.
   Allowed values are `private` or `public`.
8. `${CREATE_PULL_SECRET}` decides whether the script should also create or update a Kubernetes pull secret.
   Set it to `true` or `false`.
9. `${PULL_SECRET_NAME}` is the Kubernetes secret name used when `${CREATE_PULL_SECRET}` is `true`.
10. `${KUBERNETES_NAMESPACE}` is the Kubernetes namespace where the pull secret should be created.
