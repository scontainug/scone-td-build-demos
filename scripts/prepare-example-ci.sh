#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 --mode <sgx|cvm> [--registry REGISTRY] [--image-pull-secret-name NAME]

Prepares the example Values.yaml files and Kubernetes pull secrets for CI.

Environment:
  REGISTRY_USER   Registry username used to create the image pull secret.
  REGISTRY_TOKEN  Registry token/password used to create the image pull secret.

Options:
  --mode <mode>              One of: sgx, cvm
  --registry <registry>      Registry hostname to use (default: registry.scontain.com)
  --image-pull-secret-name   Pull secret name to use (default: sconeapps)
  --help                     Show this help message and exit.
USAGE
}

mode=""
registry="${REGISTRY:-registry.scontain.com}"
image_pull_secret_name="${IMAGE_PULL_SECRET_NAME:-sconeapps}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --registry)
      registry="${2:-}"
      shift 2
      ;;
    --image-pull-secret-name)
      image_pull_secret_name="${2:-}"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
    *)
      echo "Error: This script does not accept positional arguments." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Error: This script does not accept positional arguments." >&2
  show_help >&2
  exit 1
fi

case "$mode" in
  sgx|cvm)
    ;;
  *)
    echo "Error: --mode must be either 'sgx' or 'cvm'." >&2
    exit 1
    ;;
esac

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Required command '$command_name' was not found." >&2
    exit 1
  fi
}

upsert_scalar() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN {
      found = 0
      in_environment = 0
    }
    /^environment:[[:space:]]*$/ {
      in_environment = 1
      print
      next
    }
    in_environment && $0 ~ ("^  " key ":") {
      print "  " key ": " value
      found = 1
      next
    }
    in_environment && $0 !~ /^  / {
      if (!found) {
        print "  " key ": " value
      }
      in_environment = 0
    }
    { print }
    END {
      if (in_environment && !found) {
        print "  " key ": " value
      }
    }
  ' "$file" >"$tmp_file"
  mv "$tmp_file" "$file"
}

ensure_namespace() {
  local namespace="$1"
  if [[ "$namespace" == "default" ]]; then
    return 0
  fi

  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
}

apply_pull_secret() {
  local namespace="$1"

  kubectl create secret docker-registry "$image_pull_secret_name" \
    --namespace "$namespace" \
    --docker-server="$registry" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
}

require_command kubectl
require_command awk

if [[ -z "${REGISTRY_USER:-}" ]]; then
  echo "Error: REGISTRY_USER must be set in the environment." >&2
  exit 1
fi

if [[ -z "${REGISTRY_TOKEN:-}" ]]; then
  echo "Error: REGISTRY_TOKEN must be set in the environment." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

all_values_files=(
  "${repo_root}/hello-world/Values.yaml"
  "${repo_root}/configmap/Values.yaml"
  "${repo_root}/web-server/Values.yaml"
  "${repo_root}/network-policy/Values.yaml"
  "${repo_root}/go-args-env-file/Values.yaml"
  "${repo_root}/flask-redis/Values.yaml"
  "${repo_root}/flask-redis-netshield/Values.yaml"
)

flag_mode_files=(
  "${repo_root}/hello-world/Values.yaml"
  "${repo_root}/web-server/Values.yaml"
)

boolean_mode_files=(
  "${repo_root}/configmap/Values.yaml"
  "${repo_root}/network-policy/Values.yaml"
  "${repo_root}/go-args-env-file/Values.yaml"
  "${repo_root}/flask-redis/Values.yaml"
  "${repo_root}/flask-redis-netshield/Values.yaml"
)

if [[ "$mode" == "sgx" ]]; then
  flag_cvm_mode="''"
  flag_scone_enclave="''"
  boolean_cvm_mode="'false'"
  boolean_scone_enclave="'false'"
else
  flag_cvm_mode="--cvm"
  flag_scone_enclave="--scone-enclave"
  boolean_cvm_mode="'true'"
  boolean_scone_enclave="'true'"
fi

for values_file in "${flag_mode_files[@]}"; do
  upsert_scalar "$values_file" "CVM_MODE" "$flag_cvm_mode"
  upsert_scalar "$values_file" "SCONE_ENCLAVE" "$flag_scone_enclave"
done

for values_file in "${boolean_mode_files[@]}"; do
  upsert_scalar "$values_file" "CVM_MODE" "$boolean_cvm_mode"
  upsert_scalar "$values_file" "SCONE_ENCLAVE" "$boolean_scone_enclave"
done

for values_file in "${all_values_files[@]}"; do
  upsert_scalar "$values_file" "IMAGE_PULL_SECRET_NAME" "$image_pull_secret_name"
  upsert_scalar "$values_file" "REGISTRY" "$registry"
done

declare -A seen_namespaces=()
target_namespaces=("default")

for values_file in "${all_values_files[@]}"; do
  namespace="$(awk -F': ' '/^  NAMESPACE:/ { gsub(/["'\''[:space:]]/, "", $2); print $2; exit }' "$values_file")"
  if [[ -n "$namespace" && -z "${seen_namespaces[$namespace]:-}" ]]; then
    seen_namespaces["$namespace"]=1
    target_namespaces+=("$namespace")
  fi
done

for namespace in "${target_namespaces[@]}"; do
  ensure_namespace "$namespace"
  apply_pull_secret "$namespace"
done

printf 'Prepared example CI configuration for mode: %s\n' "$mode"
printf 'Registry: %s\n' "$registry"
printf 'Image pull secret: %s\n' "$image_pull_secret_name"
printf 'Namespaces:\n'
for namespace in "${target_namespaces[@]}"; do
  printf '  - %s\n' "$namespace"
done
