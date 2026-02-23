#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
IMAGE=""
CAS_ADDR="cas.default"
PULL_SECRET="scontain"

usage() {
  echo "Usage: $0 --image <IMAGE> --cas <CAS_ADDR>.</CAS_NAMESPACE> --pullsecret <SECRET>"
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

FOLDER_READER_DIR="$SCRIPT_DIR/folder-reader"

MANIFEST_TEMPLATE="$SCRIPT_DIR/manifest.template.yaml"
SCONE_TEMPLATE="$SCRIPT_DIR/scone.template.yaml"

MANIFEST_RENDERED="$SCRIPT_DIR/manifest.yaml"
SCONE_RENDERED="$SCRIPT_DIR/scone.yaml"
PROD_MANIFEST="$SCRIPT_DIR/manifest.prod.sanitized.yaml"

JOB_NAME="my-rust-app"
NAMESPACE="default"

echo "Image: $IMAGE"
echo "Repo root: $REPO_ROOT"

# ---- Sanity checks ---------------------------------------------------------
command -v docker >/dev/null || { echo "docker not found"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v envsubst >/dev/null || { echo "envsubst not found"; exit 1; }
command -v yq >/dev/null || { echo "yq not found"; exit 1; }
command -v cargo >/dev/null || { echo "cargo not found"; exit 1; }

[[ -d "$FOLDER_READER_DIR" ]] || { echo "folder-reader not found"; exit 1; }
[[ -f "$MANIFEST_TEMPLATE" ]] || { echo "manifest.template.yaml not found"; exit 1; }
[[ -f "$SCONE_TEMPLATE" ]] || { echo "scone.template.yaml not found"; exit 1; }

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
# shellcheck disable=SC2329
cleanup() {
  echo "Cleanup"

  if [[ -f "$PROD_MANIFEST" ]]; then
    kubectl delete -f "$PROD_MANIFEST" --ignore-not-found || true
  fi

  rm -f \
    "$MANIFEST_RENDERED" \
    "$SCONE_RENDERED" \
    "$PROD_MANIFEST" \
    2>/dev/null || true
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# Pull secret check (UNCHANGED)
# ---------------------------------------------------------------------------
check_pull_secret() {
    echo "Checking pull secret in namespace '$NAMESPACE'..."
    
    local kubeconfig_info=""
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Namespace '$NAMESPACE' does not exist yet${kubeconfig_info}"
        echo "You may need to create it before deploying: kubectl create namespace $NAMESPACE"
        exit 1
    fi
    
    # Check if pull secret exists in the namespace
    if kubectl get secret "$PULL_SECRET" -n "$NAMESPACE" &>/dev/null; then
        echo "Pull secret '$PULL_SECRET' found in namespace '$NAMESPACE'${kubeconfig_info}"
    else
        echo "Pull secret '$PULL_SECRET' NOT found in namespace '$NAMESPACE'${kubeconfig_info}"
        echo "You may need to create it before deploying:"
        echo -e "\n kubectl create secret docker-registry $PULL_SECRET \\"
        echo -e "    --docker-server=<your-registry-server> \\"
        echo -e "    --docker-username=<your-username> \\"
        echo -e "    --docker-password=<your-password> \\"
        echo -e "    --docker-email=<your-email> \\"
        echo -e "    -n $NAMESPACE\n"
        exit 1
    fi
}

check_pull_secret

# ---- Build k8s-scone --------------------------------------------------------
echo "Building k8s-scone"
pushd "$K8S_SCONE_DIR" >/dev/null
cargo build
popd >/dev/null

[[ -x "$K8S_SCONE_BIN" ]] || { echo "k8s-scone binary missing"; exit 1; }

# ---- Build folder-reader image ---------------------------------------------
echo "Building folder-reader image"
pushd "$FOLDER_READER_DIR" >/dev/null
docker build -t "$IMAGE" .
docker push "$IMAGE"
popd >/dev/null

# ---- Render templates -------------------------------------------------------
echo "Rendering manifest and SCONE templates"
export DEMO_IMAGE="$IMAGE"
export SCRIPT_DIR="$SCRIPT_DIR"
export CAS_ADDR="$CAS_ADDR"

envsubst < "$MANIFEST_TEMPLATE" > "$MANIFEST_RENDERED"
envsubst < "$SCONE_TEMPLATE" > "$SCONE_RENDERED"

# ---- Generate SCONE session -------------------------------------------------
echo "Generating SCONE session"
echo "$SCONE_RENDERED"

"$K8S_SCONE_BIN" from -y "$SCONE_RENDERED" 

docker push "$IMAGE"-scone
[[ -f "$PROD_MANIFEST" ]] || { echo "manifest.prod.sanitized.yaml not generated"; exit 1; }

# ---- Deploy -----------------------------------------------------------------
echo "Applying SCONE-protected manifest"
kubectl apply -f "$PROD_MANIFEST"

echo "Waiting for Job completion"
kubectl wait --for=condition=complete job/$JOB_NAME --timeout=300s

# ---- Extract expected files -------------------------------------------------
echo "Extracting expected ConfigMap files"

declare -A VOLUME_KEYS
declare -A CONTAINER_KEYS

# shellcheck disable=SC2016
mapfile -t VOLUME_KEY_LINES < <(
  yq -r '
    .spec.template.spec.volumes[]
    | select(.configMap != null and .configMap.items != null)
    | .name as $v
    | .configMap.items[]
    | "\($v)|\(.key)"
  ' "$MANIFEST_RENDERED"
)

for line in "${VOLUME_KEY_LINES[@]}"; do
  [[ -z "$line" ]] && continue
  vol="${line%%|*}"
  key="${line##*|}"
  [[ -z "$vol" || -z "$key" || "$vol" == -* ]] && continue
  VOLUME_KEYS["$vol"]+="$key "
done

# shellcheck disable=SC2016
mapfile -t CONTAINER_VOLUME_LINES < <(
  yq -r '
    .spec.template.spec.containers[]
    | .name as $c
    | .volumeMounts[]
    | "\($c)|\(.name)"
  ' "$MANIFEST_RENDERED"
)

for line in "${CONTAINER_VOLUME_LINES[@]}"; do
  [[ -z "$line" ]] && continue
  container="${line%%|*}"
  volume="${line##*|}"
  [[ -z "$container" || -z "$volume" ]] && continue
  for key in ${VOLUME_KEYS[$volume]:-}; do
    CONTAINER_KEYS["$container"]+="$key "
  done
done

# ---- Validate logs ----------------------------------------------------------
STATUS=0

for container in "${!CONTAINER_KEYS[@]}"; do
  echo "Logs from $container"
  logs="$(kubectl logs job/$JOB_NAME -c "$container")"
  echo "$logs"
  echo

  for file in ${CONTAINER_KEYS[$container]}; do
    if echo "$logs" | grep -q "filename: \"$file\""; then
      echo "  ✔ $file found"
    else
      echo "  ✘ $file missing"
      STATUS=1
    fi
  done
  echo
done

# ---- Result -----------------------------------------------------------------
if [[ $STATUS -eq 0 ]]; then
  echo "✅ TEST PASSED: build → session → deploy → validation OK"
else
  echo "❌ TEST FAILED"
fi

exit $STATUS
