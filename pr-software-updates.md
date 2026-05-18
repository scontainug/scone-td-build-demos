## Add `software-updates` demo

Adds a new example showing how to perform a confidential software update using `scone-td-build`. Two versions of a Python application are built and deployed as Kubernetes Jobs. The demo shows that `API_PASSWORD` is preserved across the update because it lives in the CAS session shared by both versions.

### What's included

- `print_env1.py` / `print_env2.py` — minimal Python scripts that print `API_USER` and an `md5` checksum of `API_PASSWORD`, then exit
- `Dockerfile` — builds either version via `--build-arg VERSION=1|2`
- `k8s/manifest.v1.template.yaml` / `k8s/manifest.v2.template.yaml` — Kubernetes `Job` templates for each version
- `scone.v1.template.yaml` / `scone.v2.template.yaml` — SCONE `Register` + `Apply` CRD templates; both share the same session name so v2 updates the existing CAS session in-place
- `environment-variables.md` — tplenv variable definitions including `API_USER` and `API_PASSWORD`
- `registry.credentials.md` — registry credential definitions (SIGNER, REGISTRY_USER, REGISTRY_TOKEN kept out of `Values.yaml`)
- `Values.yaml` — default values following the same structure as other demos (`NAMESPACE: default`, no secrets stored)
- Entry added to root `README.md`
- `scripts/software-updates.sh` and `docs/software-updates.sh` generated from the README
- `scripts/prepare-example-ci.sh` updated to include `software-updates/Values.yaml`

### Demo flow

1. Build and push native images for both versions
2. **Part 0 — Native run**: deploy v1 and v2 as plain Jobs to confirm the app works before adding SCONE protection
3. **Part 1 — SCONE v1**: build the confidential image, create the CAS session, deploy and verify
4. **Part 2 — Software update**: build the confidential v2 image (updates the existing CAS session), redeploy, and verify the `API_PASSWORD` checksum matches v1

### Key design decisions

- Uses Kubernetes `Job` (not `Deployment`) since the app runs once and exits — consistent with other simple demos
- `API_USER` and `API_PASSWORD` are plain env vars in the manifest; `scone-td-build` encrypts them into the CAS session (`secretKeyRef` is not supported)
- Both SCONE configs share `metadata.name: software-updates-demo` so the v2 build updates the existing session rather than creating a new one, preserving the secret
