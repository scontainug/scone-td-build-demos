#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
IMAGE=""
CAS_ADDR="cas.default"
PULL_SECRET="scontain"
STORAGE_JSON="web-server.json"

usage() {
  echo "Usage: $0 --image <IMAGE> [--cas <CAS_ADDR>] [--pullsecret <SECRET>] [--storage <STORAGE_JSON>]"
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
    -s|--storage)
      STORAGE_JSON="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ -z "$IMAGE" ]] && usage

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

K8S_SCONE_BIN="$REPO_ROOT/target/debug/k8s-scone"

WEB_SERVER_DIR="$SCRIPT_DIR"
MANIFEST_TEMPLATE="$WEB_SERVER_DIR/manifest.template.yaml"
MANIFEST="$WEB_SERVER_DIR/manifest.yaml"
MANIFEST_CLEANED="$WEB_SERVER_DIR/manifest.cleaned.yaml"

NAMESPACE="default"
DEPLOYMENT_NAME="web-server"
PORT_LOCAL=50000
PORT_REMOTE=8000

echo "Image:     $IMAGE"
echo "CAS:       $CAS_ADDR"
echo "Repo root: $REPO_ROOT"

# ---- Sanity checks ---------------------------------------------------------
command -v docker   >/dev/null || { echo "docker not found";   exit 1; }
command -v kubectl  >/dev/null || { echo "kubectl not found";  exit 1; }
command -v cargo    >/dev/null || { echo "cargo not found";    exit 1; }
command -v curl     >/dev/null || { echo "curl not found";     exit 1; }
command -v envsubst >/dev/null || { echo "envsubst not found"; exit 1; }

[[ -f "$MANIFEST_TEMPLATE" ]] || { echo "manifest.template.yaml not found at $MANIFEST_TEMPLATE"; exit 1; }

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
cleanup() {
  echo "Cleanup"
  # Kill any lingering port-forward
  if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
    kill "$PORT_FORWARD_PID" 2>/dev/null || true
  fi
  if [[ -f "$MANIFEST_CLEANED" ]]; then
    kubectl delete -f "$MANIFEST_CLEANED" --ignore-not-found || true
  fi
  rm -f "$MANIFEST" "$MANIFEST_CLEANED" 2>/dev/null || true
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# Pull secret check
# ---------------------------------------------------------------------------
check_pull_secret() {
  echo "Checking pull secret '$PULL_SECRET' in namespace '$NAMESPACE'..."

  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "Namespace '$NAMESPACE' does not exist."
    echo "Create it with: kubectl create namespace $NAMESPACE"
    exit 1
  fi

  if kubectl get secret "$PULL_SECRET" -n "$NAMESPACE" &>/dev/null; then
    echo "Pull secret '$PULL_SECRET' found in namespace '$NAMESPACE'."
  else
    echo "Pull secret '$PULL_SECRET' NOT found in namespace '$NAMESPACE'."
    echo "Create it with:"
    echo -e "\n  kubectl create secret docker-registry $PULL_SECRET \\"
    echo -e "    --docker-server=registry.scontain.com \\"
    echo -e "    --docker-username=\$REGISTRY_USER \\"
    echo -e "    --docker-password=\$REGISTRY_TOKEN \\"
    echo -e "    -n $NAMESPACE\n"
    exit 1
  fi
}

check_pull_secret

# ---- Build k8s-scone -------------------------------------------------------
echo "Building k8s-scone"
pushd "$REPO_ROOT" >/dev/null
cargo build
popd >/dev/null

[[ -x "$K8S_SCONE_BIN" ]] || { echo "k8s-scone binary missing after build"; exit 1; }

# ---- Build & push web-server image -----------------------------------------
echo "Building web-server image: $IMAGE"
pushd "$WEB_SERVER_DIR" >/dev/null
docker build -t "$IMAGE" .
docker push "$IMAGE"
popd >/dev/null

# ---- Render manifest template ----------------------------------------------
echo "Rendering manifest template"
export IMAGE_NAME="$IMAGE"
envsubst < "$MANIFEST_TEMPLATE" > "$MANIFEST"

# ---- Register the image with SCONE -----------------------------------------
echo "Registering image with k8s-scone"
"$K8S_SCONE_BIN" register \
  --protected-image   "$IMAGE" \
  --unprotected-image "$IMAGE" \
  --manifest-env SCONE_PRODUCTION=0 \
  --enforce /app/web-server \
  -s "$STORAGE_JSON"

echo "Pushing SCONE-protected image"
docker push "$IMAGE"-scone

# ---- Apply / convert the manifest ------------------------------------------
echo "Converting manifest with k8s-scone apply"

"$K8S_SCONE_BIN" apply \
  -f "$MANIFEST" \
  -c "$CAS_ADDR" \
  -p \
  -s "$STORAGE_JSON" \
  --manifest-env SCONE_SYSLIBS=1 \
  --manifest-env SCONE_PRODUCTION=0 \
  --manifest-env SCONE_LOG=DEBUG \
  --manifest-env SCONE_VERSION=1 \
  --session-env SCONE_LOG=DEBUG \
  --session-env SCONE_VERSION=1  

[[ -f "$MANIFEST_CLEANED" ]] || { echo "manifest.cleaned.yaml not generated"; exit 1; }

# ---- Deploy ----------------------------------------------------------------
echo "Deploying web-server"
kubectl apply -f "$MANIFEST_CLEANED"

echo "Waiting for Deployment rollout"
kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=300s

sleep 30
# ---- Port-forward ----------------------------------------------------------
echo "Starting port-forward on localhost:$PORT_LOCAL → $DEPLOYMENT_NAME:$PORT_REMOTE"
kubectl port-forward deployment/"$DEPLOYMENT_NAME" "$PORT_LOCAL:$PORT_REMOTE" &
PORT_FORWARD_PID=$!

# Give port-forward a moment to be ready
sleep 3

BASE_URL="http://localhost:$PORT_LOCAL"

# ---- Run tests -------------------------------------------------------------
echo ""
echo "Running endpoint tests against $BASE_URL"
STATUS=0

assert_http_ok() {
  local label="$1"
  local url="$2"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [[ "$http_code" == "200" ]]; then
    echo "  ✔ $label (HTTP $http_code)"
  else
    echo "  ✘ $label (HTTP $http_code)"
    STATUS=1
  fi
}

assert_body_contains() {
  local label="$1"
  local url="$2"
  local pattern="$3"
  local body
  body=$(curl -s "$url")
  if echo "$body" | grep -q "$pattern"; then
    echo "  ✔ $label"
  else
    echo "  ✘ $label (pattern '$pattern' not found in: $body)"
    STATUS=1
  fi
}

# /gen — should return {"password": "..."}
assert_body_contains "GET /gen returns password field"    "$BASE_URL/gen"                         'password'

# /path — should return {"name": ..., "content": ...}
assert_http_ok       "GET /path responds 200"             "$BASE_URL/path"

# /env/:env
assert_body_contains "GET /env/PLAYER_INITIAL_LIVES"      "$BASE_URL/env/PLAYER_INITIAL_LIVES"    '3'
assert_body_contains "GET /env/UI_PROPERTIES_FILE_NAME"   "$BASE_URL/env/UI_PROPERTIES_FILE_NAME" 'user-interface.properties'
assert_body_contains "GET /env/SECRET_ENV"                "$BASE_URL/env/SECRET_ENV"              'value-2'
assert_body_contains "GET /env/SIMPLE_ENV"                "$BASE_URL/env/SIMPLE_ENV"              'IM WORKING WELL'

echo ""

# ---- Result ----------------------------------------------------------------
if [[ $STATUS -eq 0 ]]; then
  echo "✅ TEST PASSED: build → register → deploy → validation OK"
else
  echo "❌ TEST FAILED"
fi

exit $STATUS
