# GitHub Actions on a Self-Hosted Runner

This repository includes a GitHub Actions workflow at [`.github/workflows/test-examples-self-hosted.yml`](.github/workflows/test-examples-self-hosted.yml) that runs all examples on a self-hosted runner against an existing Kubernetes cluster.

The job itself runs inside the container image `registry.scontain.com/workshop/scone`, so the SCONE and Kubernetes tools come from that image instead of being installed directly on the runner host.

The workflow uses [`./scripts/run-all-scripts.sh`](./scripts/run-all-scripts.sh) and runs the examples twice:

1. in SGX mode
2. in CVM mode

For pull requests from forks, the workflow is skipped because GitHub does not expose repository secrets to those runs.

Before each run it calls [`./scripts/prepare-example-ci.sh`](./scripts/prepare-example-ci.sh) to:

- update the example `Values.yaml` files for the selected mode
- ensure the required Kubernetes image-pull secrets exist

## Required GitHub repository secrets

The workflow expects these repository secrets:

- `KUBECONFIG_B64`: base64-encoded kubeconfig for the cluster that the self-hosted runner can access
- `REGISTRY_USER`: username for `registry.scontain.com`
- `REGISTRY_TOKEN`: pull token/password for `registry.scontain.com`

You do not need a GitHub secret for `SIGNER`. The workflow derives it inside the job container via `scone self show-session-signing-key`.
The registry credentials are used both to pull the GitHub Actions job container, for `docker login` inside the job container, and for Kubernetes image-pull secrets inside the cluster.

## Runner prerequisites

The self-hosted runner host is expected to provide:

- `bash`
- `docker`

The workflow starts the job inside `registry.scontain.com/workshop/scone` and mounts the host Docker socket into that container so the examples can still run `docker build` and `docker push`.

Inside the job container, the workflow checks for these commands before running the examples:

- `bash`
- `docker`
- `kubectl`
- `scone`
- `scone-td-build`
- `tplenv`
- `retry-spinner`
- `openssl`
- `jq`
- `curl`
- `cargo`

## How to generate the secret values

### `KUBECONFIG_B64`

If your runner already uses a kubeconfig locally, you can base64-encode it:

```bash
base64 < ~/.kube/config | tr -d '\n'
```

If you use `KUBECONFIG`, point the setup script to that file with `--kubeconfig`.

### `REGISTRY_USER` and `REGISTRY_TOKEN`

Use the registry credentials for `registry.scontain.com`.

- The username is your registry login.
- The token can be created as described in [registry docs](https://sconedocs.github.io/registry/).

### Required GitLab group or project access

If `REGISTRY_USER` is backed by a GitLab account or token and you keep the checked-in default image names, the workflow touches these registry paths:

- pull the job container from `workshop/scone`
- push native or confidential example images under `k8s-scone-images/*`
- push native or confidential example images under `workshop/*`

The easiest GitLab setup is group-level access:

- `Developer` on the `k8s-scone-images` group
- `Developer` on the `workshop` group

That covers both pull and push for every default image used by the workflow, including `registry.scontain.com/workshop/scone`.

If you want a narrower project-level setup, use:

- `Reporter` on `workshop/scone` for pulling the GitHub Actions job container
- `Developer` on `k8s-scone-images/configmap`
- `Developer` on `k8s-scone-images/flask-redis`
- `Developer` on `k8s-scone-images/go-args-env-file`
- `Developer` on `k8s-scone-images/hello-world`
- `Developer` on `k8s-scone-images/web-server`
- `Developer` on `workshop/configmap`
- `Developer` on `workshop/hello-world`
- `Developer` on `workshop/network-policy`
- `Developer` on `workshop/web-server`

Notes:

- `flask-redis-netshield` reuses `k8s-scone-images/flask-redis`
- `go-args-env-file` keeps both its native and confidential images in `k8s-scone-images/go-args-env-file`
- The workflow also pulls public upstream images such as `redis:7-alpine` and `ghcr.io/scontain/golang`; those are outside this GitLab access set

## Set the secrets automatically with `gh`

The easiest setup path is:

```bash
gh auth login
./scripts/setup-github-actions-secrets.sh
```

By default, the script:

- uses the current repository from `gh`
- reads the kubeconfig from `$KUBECONFIG` or `~/.kube/config`
- prompts for `REGISTRY_USER` and `REGISTRY_TOKEN` if they are not already set in your shell
- writes the required repo secrets with `gh secret set`

If your images live in a GitLab container registry, the script can also try to create the registry credential for you:

```bash
gh auth login
./scripts/setup-github-actions-secrets.sh --create-gitlab-pat
```

With `--create-gitlab-pat`, the script first tries to create a GitLab personal access token with `read_registry` and `write_registry`. GitLab only allows that through the API for administrators, so for normal users the script falls back to a minimal group or project deploy token with the same registry scopes.

You can point the GitLab bootstrap flow at a specific GitLab instance or project with `--gitlab-url`, `--gitlab-project`, `--gitlab-group`, and `--gitlab-bootstrap-token`.

This flag only creates the `REGISTRY_USER` and `REGISTRY_TOKEN` secret values. If you want the workflow itself to pull and push images from GitLab Container Registry, make sure the workflow `REGISTRY` value and the example image names also point at your GitLab registry.

You can also run it non-interactively:

```bash
REGISTRY_USER='your-user' \
REGISTRY_TOKEN='your-token' \
./scripts/setup-github-actions-secrets.sh \
  --repo OWNER/REPO \
  --kubeconfig ~/.kube/config \
  --non-interactive
```

## Workflow behavior

The workflow:

1. checks out the repository
2. starts the job in `registry.scontain.com/workshop/scone`
3. writes `KUBECONFIG_B64` to a kubeconfig file inside the job container
4. validates the toolchain inside the job container
5. prepares SGX values and image-pull secrets
6. runs `./scripts/run-all-scripts.sh --continue-on-failure`
7. prepares CVM values and image-pull secrets
8. runs `./scripts/run-all-scripts.sh --continue-on-failure` again
9. fails the workflow if either SGX or CVM had failing examples

The runner uses the existing Kubernetes cluster referenced by the provided kubeconfig. No cluster is created by the workflow itself.
