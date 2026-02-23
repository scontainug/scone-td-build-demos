#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
IMAGE=""
CAS_ADDR="cas.default"
PULL_SECRET="scontain"

usage() {
  echo "Usage: $0 --image <IMAGE> --cas <CAS_ADDR> --pullsecret <SECRET>"
  echo
  echo "Flags:"
  echo "  -i, --image        Image name (required)"
  echo "  -c, --cas          CAS address, e.g. cas.default (required)"
  echo "  -p, --pullsecret   Kubernetes image pull secret (required)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--image)
      IMAGE="$2"
      shift 2
      ;;
    -c|--cas)
      CAS_ADDR="$2"
      shift 2
      ;;
    -p|--pullsecret)
      PULL_SECRET="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ -z "$IMAGE" || -z "$CAS_ADDR" || -z "$PULL_SECRET" ]] && usage

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

K8S_SCONE_DIR="$REPO_ROOT"
K8S_SCONE_BIN="$K8S_SCONE_DIR/target/debug/k8s-scone"

HELLO_DIR="$SCRIPT_DIR/hello-world"

MANIFEST_TEMPLATE="$SCRIPT_DIR/manifest.job.template.yaml"
MANIFEST="$SCRIPT_DIR/manifest.job.yaml"
CLEANED_MANIFEST="$SCRIPT_DIR/manifest.job.cleaned.yaml"
STORAGE_JSON="$SCRIPT_DIR/storage.json"

JOB_NAME="hello-world"
NAMESPACE="default"

# ---------------------------------------------------------------------------
# Cleanup (always runs)
# ---------------------------------------------------------------------------
cleanup() {
  echo "Cleanup"

  kubectl delete -f "$CLEANED_MANIFEST" --ignore-not-found || true

  rm -f "$MANIFEST" "$CLEANED_MANIFEST" "$STORAGE_JSON" 2>/dev/null || true

  if [[ -d "$HELLO_DIR" ]]; then
    rm -rf "$HELLO_DIR"
    echo "Removed hello-world Cargo project"
  fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
command -v docker >/dev/null || { echo "docker not found"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v cargo >/dev/null || { echo "cargo not found"; exit 1; }
command -v envsubst >/dev/null || { echo "envsubst not found"; exit 1; }

[[ -f "$MANIFEST_TEMPLATE" ]] || { echo "manifest.job.template.yaml not found"; exit 1; }

check_pull_secret() {
  echo "Checking pull secret in namespace '$NAMESPACE'..."

  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "Namespace '$NAMESPACE' does not exist"
    exit 1
  fi

  if kubectl get secret "$PULL_SECRET" -n "$NAMESPACE" &>/dev/null; then
    echo "Pull secret '$PULL_SECRET' found"
  else
    echo "Pull secret '$PULL_SECRET' NOT found in namespace '$NAMESPACE'"
    exit 1
  fi
}

check_pull_secret

echo "Image:        $IMAGE"
echo "CAS address:  $CAS_ADDR"
echo "Pull secret: $PULL_SECRET"

# ---------------------------------------------------------------------------
# Build k8s-scone
# ---------------------------------------------------------------------------
echo "Building k8s-scone"
pushd "$K8S_SCONE_DIR" >/dev/null
cargo build
popd >/dev/null

[[ -x "$K8S_SCONE_BIN" ]] || { echo "k8s-scone binary missing"; exit 1; }

# ---------------------------------------------------------------------------
# Create hello-world app
# ---------------------------------------------------------------------------
echo "Creating hello-world Rust project"
pushd "$SCRIPT_DIR" >/dev/null
cargo new hello-world
popd >/dev/null

# ---------------------------------------------------------------------------
# Build and push image
# ---------------------------------------------------------------------------
echo "Building hello-world image"
pushd "$SCRIPT_DIR" >/dev/null
docker build -t "$IMAGE" .
docker push "$IMAGE"
popd >/dev/null

# ---------------------------------------------------------------------------
# Register image for SCONE
# ---------------------------------------------------------------------------
echo "Registering image in k8s-scone"
"$K8S_SCONE_BIN" register \
  --protected-image "$IMAGE" \
  --unprotected-image rust:latest \
  --manifest-env SCONE_PRODUCTION=0 \
  -s "$STORAGE_JSON"

docker push "$IMAGE-scone"

# ---------------------------------------------------------------------------
# Generate manifest from template
# ---------------------------------------------------------------------------
echo "Generating manifest.job.yaml from template"

export IMAGE
export PULL_SECRET
export NAMESPACE
export JOB_NAME

envsubst < "$MANIFEST_TEMPLATE" > "$MANIFEST"

# ---------------------------------------------------------------------------
# Apply SCONE manifest translation
# ---------------------------------------------------------------------------
echo "Applying SCONE manifest translation"
"$K8S_SCONE_BIN" apply \
  -f "$MANIFEST" \
  -c "$CAS_ADDR" \
  -p \
  -s "$STORAGE_JSON" \
  --manifest-env SCONE_SYSLIBS=1 \
  --manifest-env SCONE_PRODUCTION=0

[[ -f "$CLEANED_MANIFEST" ]] || { echo "Cleaned manifest not generated"; exit 1; }

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
echo "Applying cleaned manifest"
kubectl apply -f "$CLEANED_MANIFEST"

echo "Waiting for Job completion"
kubectl wait --for=condition=complete job/$JOB_NAME --timeout=300s

# ---------------------------------------------------------------------------
# Validate logs
# ---------------------------------------------------------------------------
echo "Fetching logs"
LOGS="$(kubectl logs job/$JOB_NAME)"
echo "$LOGS"

if echo "$LOGS" | grep -qi "hello"; then
  echo "✅ TEST PASSED: hello-world output found"
else
  echo "❌ TEST FAILED: hello-world output not found"
  exit 1
fi
