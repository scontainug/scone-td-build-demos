# Storing Private Container Images on GitHub

GitHub provides a container registry where you can store container
images such as Docker images.

The registry is called:

-   GitHub Container Registry (`ghcr.io`)

Images are stored under the domain:

    ghcr.io

This guide explains how to create a **private container image
repository** and push images to it.

------------------------------------------------------------------------

# Automation

This repository includes an automation script for this workflow (note: this is generated code - use with care):

```bash
./scripts/create-own-repository.sh
```

It uses:

- `tplenv` with [`creating-own-repository/environment-variables.md`](creating-own-repository/environment-variables.md)
- persisted defaults in [`creating-own-repository/Values.yaml`](creating-own-repository/Values.yaml)
- `gh` to create or update the GitHub repository
- `gh auth token` for Docker login and the optional Kubernetes pull secret

GitHub CLI does not currently expose a direct command to create a separate
fine-grained PAT. This automation therefore refreshes `gh` authentication with
package scopes and reuses the resulting GitHub token for GHCR operations.

------------------------------------------------------------------------

# 1. Create a GitHub Repository

First create a normal GitHub repository.

1.  Go to GitHub.
2.  Click **New Repository**.
3.  Choose a name (for example `myapp`).
4.  Select **Private** if you want the source code to be private.
5.  Click **Create Repository**.

Example repository:

    github.com/myorg/myapp

------------------------------------------------------------------------

# 2. Understand the Container Image Name

Container images stored in GitHub Container Registry follow this format:

    ghcr.io/OWNER/IMAGE:TAG

Example:

    ghcr.io/myorg/myapp:1.0

Meaning:

   Part     |   Meaning 
 -----------|-----------------------------
  `ghcr.io`  | Container registry
  `myorg`   |  GitHub user or organization
  `myapp`   |  Image repository
  `1.0`     |  Version tag

------------------------------------------------------------------------

# 3. Create a Personal Access Token

To push private images you need authentication.

1.  Open **GitHub → Settings**
2.  Go to **Developer Settings**
3.  Select **Personal Access Tokens**
4.  Create a new **Fine-grained token**

Required permission:

    packages: write

Save the token.

------------------------------------------------------------------------

# 4. Login to the Registry

Use Docker to authenticate to GitHub Container Registry.

``` bash
docker login ghcr.io
```

Enter:

    Username: your GitHub username
    Password: your Personal Access Token

------------------------------------------------------------------------

# 5. Build a Container Image

Create an image locally.

Example:

``` bash
docker build -t ghcr.io/myorg/myapp:1.0 .
```

This command:

-   builds the image
-   assigns it the correct registry name

------------------------------------------------------------------------

# 6. Push the Image to GitHub

Upload the image to the registry.

``` bash
docker push ghcr.io/myorg/myapp:1.0
```

After pushing, the image will appear in:

    GitHub → your repository → Packages

------------------------------------------------------------------------

# 7. Make the Image Private

To change visibility:

1.  Go to **GitHub → Packages**
2.  Select your container image
3.  Open **Package settings**
4.  Set visibility to:

```{=html}
<!-- -->
```
    Private

Now only authorized users can pull the image.

------------------------------------------------------------------------

# 8. Pull the Private Image

Users must authenticate before downloading.

``` bash
docker login ghcr.io
docker pull ghcr.io/myorg/myapp:1.0
```

------------------------------------------------------------------------

# 9. Using Private Images in Kubernetes

Kubernetes needs credentials to pull private images.

Create a pull secret:

``` bash
kubectl create secret docker-registry ghcr   --docker-server=ghcr.io   --docker-username=USERNAME   --docker-password=TOKEN
```

Then reference the secret in a deployment.

------------------------------------------------------------------------

# 10. Typical Workflow

    Developer -> build image -> push to ghcr.io -> Kubernetes pulls image -> container runs

------------------------------------------------------------------------

# Summary

Steps to store private container images:

1.  Create a GitHub repository
2.  Create a Personal Access Token
3.  Login to `ghcr.io`
4.  Build an image
5.  Push the image
6.  Set the package visibility to **Private**

Example image reference:

    ghcr.io/myorg/myapp:1.0
