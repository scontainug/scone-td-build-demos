#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--non-interactive]

Automates the workflow from CreatingOwnRepository.md using tplenv, gh, docker,
and optionally kubectl.

Options:
  --help             Show this help message and exit.
  --non-interactive  Use existing values without forcing confirmation.
USAGE
}

NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      unset CONFIRM_ALL_ENVIRONMENT_VARIABLES || true
      shift
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

if ! $NON_INTERACTIVE; then
  CONFIRM_ALL_ENVIRONMENT_VARIABLES="--force"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
workflow_dir="${repo_root}/creating-own-repository"
values_file="${workflow_dir}/Values.yaml"
variables_file="${workflow_dir}/environment-variables.md"
required_package_scopes="read:packages,write:packages,delete:packages"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Required command '$command_name' was not found." >&2
    exit 1
  fi
}

normalize_bool() {
  local value="${1,,}"
  case "$value" in
    1|true|yes|y|on)
      printf 'true'
      ;;
    0|false|no|n|off)
      printf 'false'
      ;;
    *)
      echo "Error: Invalid boolean value '$1'." >&2
      exit 1
      ;;
  esac
}

scope_is_present() {
  local scopes_csv="$1"
  local wanted="$2"
  local scope

  IFS=',' read -r -a scope_list <<<"$scopes_csv"
  for scope in "${scope_list[@]}"; do
    scope="${scope//[[:space:]]/}"
    if [[ "$scope" == "$wanted" ]]; then
      return 0
    fi
  done

  return 1
}

get_current_scopes() {
  gh api -i user 2>/dev/null | awk -F': ' 'tolower($1)=="x-oauth-scopes" { gsub(/\r/, "", $2); print $2 }'
}

ensure_github_auth() {
  local current_scopes

  if gh api user >/dev/null 2>&1; then
    current_scopes="$(get_current_scopes)"
    if [[ -z "$current_scopes" ]]; then
      return 0
    fi

    if scope_is_present "$current_scopes" "read:packages" && scope_is_present "$current_scopes" "write:packages"; then
      return 0
    fi

    if [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
      echo "Error: The provided GH_TOKEN/GITHUB_TOKEN is missing required package scopes." >&2
      echo "Need at least: ${required_package_scopes}" >&2
      exit 1
    fi

    echo "Refreshing gh authentication to include package scopes..." >&2
    gh auth refresh --scopes "${required_package_scopes}"
    return 0
  fi

  if [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    echo "Error: The provided GH_TOKEN/GITHUB_TOKEN could not authenticate to GitHub." >&2
    exit 1
  fi

  echo "Logging into GitHub with gh..." >&2
  gh auth login --web --git-protocol https --scopes "${required_package_scopes}"
}

set_package_visibility() {
  local owner_type="$1"
  local package_name="$2"
  local visibility="$3"
  local endpoint
  local attempt

  case "$owner_type" in
    User)
      endpoint="/user/packages/container/${package_name}/visibility"
      ;;
    Organization)
      endpoint="/orgs/${GITHUB_OWNER}/packages/container/${package_name}/visibility"
      ;;
    *)
      echo "Warning: Unknown GitHub owner type '${owner_type}', skipping package visibility update." >&2
      return 0
      ;;
  esac

  for attempt in {1..10}; do
    if gh api --method PATCH "$endpoint" -f visibility="$visibility" --silent >/dev/null 2>&1; then
      printf 'Set GHCR package visibility to %s.\n' "$visibility"
      return 0
    fi
    sleep 3
  done

  echo "Warning: Could not update package visibility via GitHub API." >&2
  echo "Warning: Check the package settings manually if needed." >&2
}

require_command gh
require_command tplenv
require_command docker

ensure_github_auth

authenticated_user="$(gh api user --jq .login)"
export GITHUB_OWNER="${GITHUB_OWNER:-$authenticated_user}"
export SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

source_dir_basename="$(basename "$SOURCE_DIR")"
export REPOSITORY_NAME="${REPOSITORY_NAME:-$source_dir_basename}"
export IMAGE_NAME="${IMAGE_NAME:-${REPOSITORY_NAME,,}}"

eval "$(tplenv \
  --file "$variables_file" \
  --values-file "$values_file" \
  --create-values-file \
  --context \
  --eval ${CONFIRM_ALL_ENVIRONMENT_VARIABLES-} \
  --output /dev/null)"

case "${REPOSITORY_VISIBILITY}" in
  private|public|internal)
    ;;
  *)
    echo "Error: REPOSITORY_VISIBILITY must be one of private, public, or internal." >&2
    exit 1
    ;;
esac

case "${PACKAGE_VISIBILITY}" in
  private|public)
    ;;
  *)
    echo "Error: PACKAGE_VISIBILITY must be either private or public." >&2
    exit 1
    ;;
esac

CREATE_PULL_SECRET="$(normalize_bool "${CREATE_PULL_SECRET}")"

SOURCE_DIR="$(cd "${SOURCE_DIR}" && pwd)"
if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: SOURCE_DIR '$SOURCE_DIR' does not exist." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_DIR}/Dockerfile" ]]; then
  echo "Error: SOURCE_DIR '$SOURCE_DIR' does not contain a Dockerfile." >&2
  exit 1
fi

repo_full_name="${GITHUB_OWNER}/${REPOSITORY_NAME}"
package_name="${IMAGE_NAME,,}"
image_ref="ghcr.io/${GITHUB_OWNER}/${package_name}:${IMAGE_TAG}"
repo_url="https://github.com/${repo_full_name}"
auth_token="$(gh auth token)"
owner_type="$(gh api "/users/${GITHUB_OWNER}" --jq .type)"

if [[ "$owner_type" == "User" && "$REPOSITORY_VISIBILITY" == "internal" ]]; then
  echo "Error: REPOSITORY_VISIBILITY=internal is only valid for organizations." >&2
  exit 1
fi

if gh repo view "$repo_full_name" >/dev/null 2>&1; then
  printf 'Repository %s already exists.\n' "$repo_full_name"
  gh repo edit "$repo_full_name" --visibility "$REPOSITORY_VISIBILITY"
else
  gh repo create "$repo_full_name" "--${REPOSITORY_VISIBILITY}"
fi

printf 'Logging Docker into ghcr.io as %s...\n' "$authenticated_user"
printf '%s\n' "$auth_token" | docker login ghcr.io -u "$authenticated_user" --password-stdin

printf 'Building image %s from %s...\n' "$image_ref" "$SOURCE_DIR"
docker build \
  --label "org.opencontainers.image.source=${repo_url}" \
  -t "$image_ref" \
  "$SOURCE_DIR"

printf 'Pushing image %s...\n' "$image_ref"
docker push "$image_ref"

set_package_visibility "$owner_type" "$package_name" "$PACKAGE_VISIBILITY"

if [[ "$CREATE_PULL_SECRET" == "true" ]]; then
  require_command kubectl
  printf 'Creating or updating pull secret %s in namespace %s...\n' "$PULL_SECRET_NAME" "$KUBERNETES_NAMESPACE"
  kubectl create secret docker-registry "$PULL_SECRET_NAME" \
    --namespace "$KUBERNETES_NAMESPACE" \
    --docker-server=ghcr.io \
    --docker-username="$authenticated_user" \
    --docker-password="$auth_token" \
    --dry-run=client \
    -o yaml | kubectl apply -f -
fi

cat <<EOF
Done.

Repository: ${repo_url}
Image:      ${image_ref}
Package:    https://github.com/${GITHUB_OWNER}?tab=packages
EOF

if [[ "$CREATE_PULL_SECRET" == "true" ]]; then
  printf 'Pull secret: %s (namespace: %s)\n' "$PULL_SECRET_NAME" "$KUBERNETES_NAMESPACE"
fi
