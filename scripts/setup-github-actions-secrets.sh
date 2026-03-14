#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 [--repo OWNER/REPO] [--kubeconfig PATH] [--registry-user USER] [--registry-token TOKEN] [--create-gitlab-pat] [--gitlab-url URL] [--gitlab-project PATH] [--gitlab-group PATH] [--gitlab-bootstrap-token TOKEN] [--gitlab-token-name NAME] [--gitlab-token-expires-at YYYY-MM-DD] [--non-interactive]

Configures the GitHub Actions repo secrets required by the self-hosted
example-test workflow.

Secrets that are set:
  - KUBECONFIG_B64
  - REGISTRY_USER
  - REGISTRY_TOKEN

Options:
  --repo OWNER/REPO                  Target GitHub repository. Defaults to the current gh repo.
  --kubeconfig PATH                  Path to the kubeconfig file. Defaults to \$KUBECONFIG or ~/.kube/config.
  --registry-user USER               Registry username. Defaults to \$REGISTRY_USER.
  --registry-token TOKEN             Registry token. Defaults to \$REGISTRY_TOKEN.
  --create-gitlab-pat                Try to create GitLab registry credentials automatically.
                                     This first tries an admin-only personal access token and
                                     then falls back to a minimal deploy token.
  --gitlab-url URL                   GitLab base URL. Defaults to \$GITLAB_URL or a GitLab origin remote.
  --gitlab-project PATH              GitLab project path, for example group/project.
                                     Defaults to \$GITLAB_PROJECT_PATH or a GitLab origin remote.
  --gitlab-group PATH                GitLab group path for group deploy token fallback.
                                     Defaults to \$GITLAB_GROUP_PATH or the parent of --gitlab-project.
  --gitlab-bootstrap-token TOKEN     GitLab token with API access and sufficient rights to create
                                     the PAT or deploy token. Defaults to \$GITLAB_BOOTSTRAP_TOKEN.
  --gitlab-token-name NAME           Name to use for the created GitLab token.
                                     Defaults to a timestamped workflow token name.
  --gitlab-token-expires-at DATE     Expiry date for the created GitLab token in YYYY-MM-DD format.
                                     Defaults to 30 days from today.
  --non-interactive                  Fail instead of prompting for missing values.
  --help                             Show this help message and exit.
USAGE
}

repo=""
kubeconfig_path=""
registry_user="${REGISTRY_USER:-}"
registry_token="${REGISTRY_TOKEN:-}"
create_gitlab_pat=false
gitlab_url="${GITLAB_URL:-}"
gitlab_project_path="${GITLAB_PROJECT_PATH:-}"
gitlab_group_path="${GITLAB_GROUP_PATH:-}"
gitlab_bootstrap_token="${GITLAB_BOOTSTRAP_TOKEN:-${GITLAB_TOKEN:-${GITLAB_PRIVATE_TOKEN:-}}}"
gitlab_token_name="${GITLAB_TOKEN_NAME:-}"
gitlab_token_expires_at="${GITLAB_TOKEN_EXPIRES_AT:-}"
gitlab_created_credential_kind=""
gitlab_last_error=""
non_interactive=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --kubeconfig)
      kubeconfig_path="${2:-}"
      shift 2
      ;;
    --registry-user)
      registry_user="${2:-}"
      shift 2
      ;;
    --registry-token)
      registry_token="${2:-}"
      shift 2
      ;;
    --create-gitlab-pat)
      create_gitlab_pat=true
      shift
      ;;
    --gitlab-url)
      gitlab_url="${2:-}"
      shift 2
      ;;
    --gitlab-project)
      gitlab_project_path="${2:-}"
      shift 2
      ;;
    --gitlab-group)
      gitlab_group_path="${2:-}"
      shift 2
      ;;
    --gitlab-bootstrap-token)
      gitlab_bootstrap_token="${2:-}"
      shift 2
      ;;
    --gitlab-token-name)
      gitlab_token_name="${2:-}"
      shift 2
      ;;
    --gitlab-token-expires-at)
      gitlab_token_expires_at="${2:-}"
      shift 2
      ;;
    --non-interactive)
      non_interactive=true
      shift
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

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Required command '$command_name' was not found." >&2
    exit 1
  fi
}

prompt_if_empty() {
  local prompt_text="$1"
  local current_value="$2"
  if [[ -n "$current_value" ]]; then
    printf '%s' "$current_value"
    return 0
  fi

  if $non_interactive; then
    echo "Error: Missing required value for ${prompt_text}." >&2
    exit 1
  fi

  read -r -p "${prompt_text}: " current_value
  printf '%s' "$current_value"
}

prompt_if_empty_secret() {
  local prompt_text="$1"
  local current_value="$2"
  if [[ -n "$current_value" ]]; then
    printf '%s' "$current_value"
    return 0
  fi

  if $non_interactive; then
    echo "Error: Missing required value for ${prompt_text}." >&2
    exit 1
  fi

  read -r -s -p "${prompt_text}: " current_value
  printf '\n' >&2
  printf '%s' "$current_value"
}

looks_like_gitlab_host() {
  local host="$1"
  [[ "$host" == *gitlab* ]]
}

infer_gitlab_remote() {
  local origin_url host path

  if [[ -n "$gitlab_url" && -n "$gitlab_project_path" ]]; then
    return 0
  fi

  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$origin_url" ]]; then
    return 0
  fi

  case "$origin_url" in
    https://*|http://*)
      host="$(printf '%s' "$origin_url" | sed -E 's#^[a-z]+://([^/]+)/.*#\1#')"
      path="$(printf '%s' "$origin_url" | sed -E 's#^[a-z]+://[^/]+/##; s#\.git$##')"
      ;;
    git@*:* )
      host="$(printf '%s' "$origin_url" | sed -E 's#^git@([^:]+):.*#\1#')"
      path="$(printf '%s' "$origin_url" | sed -E 's#^git@[^:]+:##; s#\.git$##')"
      ;;
    ssh://git@*)
      host="$(printf '%s' "$origin_url" | sed -E 's#^ssh://git@([^/]+)/.*#\1#')"
      path="$(printf '%s' "$origin_url" | sed -E 's#^ssh://git@[^/]+/##; s#\.git$##')"
      ;;
    *)
      return 0
      ;;
  esac

  if ! looks_like_gitlab_host "$host"; then
    return 0
  fi

  if [[ -z "$gitlab_url" ]]; then
    gitlab_url="https://${host}"
  fi

  if [[ -z "$gitlab_project_path" ]]; then
    gitlab_project_path="$path"
  fi
}

default_gitlab_token_name() {
  local name_base
  if [[ -n "$gitlab_project_path" ]]; then
    name_base="${gitlab_project_path##*/}"
  elif [[ -n "$repo" ]]; then
    name_base="${repo##*/}"
  else
    name_base="registry"
  fi
  printf '%s' "${name_base}-github-actions-$(date -u +%Y%m%d%H%M%S)"
}

urlencode() {
  local value="$1"
  jq -rn --arg value "$value" '$value | @uri'
}

gitlab_error_message() {
  local body="$1"
  if jq -e . >/dev/null 2>&1 <<<"$body"; then
    jq -r '(.message // .error // .errors // .) | tostring' <<<"$body" 2>/dev/null
  else
    printf '%s' "$body"
  fi
}

gitlab_api_request() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local response_file status url

  url="${gitlab_url%/}/api/v4${endpoint}"
  response_file="$(mktemp)"

  if [[ -n "$data" ]]; then
    if ! status="$(curl -sS -o "$response_file" -w '%{http_code}' \
      --request "$method" \
      --header "PRIVATE-TOKEN: ${gitlab_bootstrap_token}" \
      --header 'Content-Type: application/json' \
      --data "$data" \
      "$url")"; then
      rm -f "$response_file"
      echo "Error: Failed to reach the GitLab API at ${url}." >&2
      exit 1
    fi
  else
    if ! status="$(curl -sS -o "$response_file" -w '%{http_code}' \
      --request "$method" \
      --header "PRIVATE-TOKEN: ${gitlab_bootstrap_token}" \
      "$url")"; then
      rm -f "$response_file"
      echo "Error: Failed to reach the GitLab API at ${url}." >&2
      exit 1
    fi
  fi

  GITLAB_API_STATUS="$status"
  GITLAB_API_BODY="$(cat "$response_file")"
  rm -f "$response_file"
}

finish_gitlab_registry_credentials() {
  if [[ -z "$registry_user" || -z "$registry_token" ]]; then
    gitlab_last_error="GitLab returned an incomplete credential pair."
    return 1
  fi

  printf 'Created GitLab %s for registry access.\n' "$gitlab_created_credential_kind"
  printf 'Using REGISTRY_USER=%s\n' "$registry_user"
}

create_gitlab_personal_access_token() {
  local payload user_id user_name

  gitlab_api_request GET "/user"
  if [[ "$GITLAB_API_STATUS" != "200" ]]; then
    gitlab_last_error="Could not resolve the current GitLab user: $(gitlab_error_message "$GITLAB_API_BODY")"
    return 1
  fi

  user_id="$(jq -r '.id // empty' <<<"$GITLAB_API_BODY")"
  user_name="$(jq -r '.username // empty' <<<"$GITLAB_API_BODY")"
  if [[ -z "$user_id" || -z "$user_name" ]]; then
    gitlab_last_error="GitLab did not return a usable current user."
    return 1
  fi

  payload="$(jq -nc \
    --arg name "$gitlab_token_name" \
    --arg expires_at "$gitlab_token_expires_at" \
    '{name: $name, expires_at: $expires_at, scopes: ["read_registry", "write_registry"]}')"

  gitlab_api_request POST "/users/${user_id}/personal_access_tokens" "$payload"
  if [[ "$GITLAB_API_STATUS" != "201" ]]; then
    gitlab_last_error="$(gitlab_error_message "$GITLAB_API_BODY")"
    return 1
  fi

  registry_user="$user_name"
  registry_token="$(jq -r '.token // empty' <<<"$GITLAB_API_BODY")"
  gitlab_created_credential_kind="personal access token"
  finish_gitlab_registry_credentials
}

create_gitlab_group_deploy_token() {
  local encoded_group payload

  if [[ -z "$gitlab_group_path" ]]; then
    gitlab_last_error="No GitLab group path is available for a group deploy token."
    return 1
  fi

  encoded_group="$(urlencode "$gitlab_group_path")"
  payload="$(jq -nc \
    --arg name "$gitlab_token_name" \
    --arg expires_at "${gitlab_token_expires_at}T00:00:00Z" \
    '{name: $name, expires_at: $expires_at, scopes: ["read_registry", "write_registry"]}')"

  gitlab_api_request POST "/groups/${encoded_group}/deploy_tokens" "$payload"
  if [[ "$GITLAB_API_STATUS" != "201" ]]; then
    gitlab_last_error="$(gitlab_error_message "$GITLAB_API_BODY")"
    return 1
  fi

  registry_user="$(jq -r '.username // empty' <<<"$GITLAB_API_BODY")"
  registry_token="$(jq -r '.token // empty' <<<"$GITLAB_API_BODY")"
  gitlab_created_credential_kind="group deploy token"
  finish_gitlab_registry_credentials
}

create_gitlab_project_deploy_token() {
  local encoded_project payload

  encoded_project="$(urlencode "$gitlab_project_path")"
  payload="$(jq -nc \
    --arg name "$gitlab_token_name" \
    --arg expires_at "${gitlab_token_expires_at}T00:00:00Z" \
    '{name: $name, expires_at: $expires_at, scopes: ["read_registry", "write_registry"]}')"

  gitlab_api_request POST "/projects/${encoded_project}/deploy_tokens" "$payload"
  if [[ "$GITLAB_API_STATUS" != "201" ]]; then
    gitlab_last_error="$(gitlab_error_message "$GITLAB_API_BODY")"
    return 1
  fi

  registry_user="$(jq -r '.username // empty' <<<"$GITLAB_API_BODY")"
  registry_token="$(jq -r '.token // empty' <<<"$GITLAB_API_BODY")"
  gitlab_created_credential_kind="project deploy token"
  finish_gitlab_registry_credentials
}

create_gitlab_registry_credentials() {
  local pat_error="" group_error="" project_error=""

  infer_gitlab_remote

  gitlab_url="$(prompt_if_empty "GitLab base URL" "$gitlab_url")"
  gitlab_project_path="$(prompt_if_empty "GitLab project path (group/project)" "$gitlab_project_path")"

  if [[ -z "$gitlab_group_path" && "$gitlab_project_path" == */* ]]; then
    gitlab_group_path="${gitlab_project_path%/*}"
  fi

  gitlab_bootstrap_token="$(prompt_if_empty_secret "GitLab bootstrap token with api scope" "$gitlab_bootstrap_token")"

  if [[ -z "$gitlab_token_name" ]]; then
    gitlab_token_name="$(default_gitlab_token_name)"
  fi

  if [[ -z "$gitlab_token_expires_at" ]]; then
    gitlab_token_expires_at="$(date -u -d '+30 days' +%F)"
  fi

  if [[ ! "$gitlab_token_expires_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: --gitlab-token-expires-at must use YYYY-MM-DD." >&2
    exit 1
  fi

  printf 'Trying to create a GitLab personal access token with read_registry/write_registry...\n'
  if create_gitlab_personal_access_token; then
    return 0
  fi
  pat_error="$gitlab_last_error"

  printf 'GitLab PAT creation failed: %s\n' "$pat_error" >&2

  if [[ -n "$gitlab_group_path" ]]; then
    printf 'Trying to create a GitLab group deploy token with read_registry/write_registry instead...\n'
    if create_gitlab_group_deploy_token; then
      return 0
    fi
    group_error="$gitlab_last_error"
    printf 'GitLab group deploy token creation failed: %s\n' "$group_error" >&2
  fi

  printf 'Trying to create a GitLab project deploy token with read_registry/write_registry instead...\n'

  if create_gitlab_project_deploy_token; then
    return 0
  fi
  project_error="$gitlab_last_error"

  echo "Error: Could not create GitLab registry credentials automatically." >&2
  echo "PAT attempt: ${pat_error}" >&2
  if [[ -n "$gitlab_group_path" ]]; then
    echo "Group deploy token attempt: ${group_error:-skipped}" >&2
  fi
  echo "Project deploy token attempt: ${project_error}" >&2
  exit 1
}

require_command gh
require_command base64
require_command tr

if $create_gitlab_pat; then
  require_command curl
  require_command jq
  require_command git
fi

if [[ -z "$repo" ]]; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi

if [[ -z "$repo" ]]; then
  echo "Error: Could not determine the target repository. Use --repo OWNER/REPO." >&2
  exit 1
fi

if [[ -z "$kubeconfig_path" ]]; then
  if [[ -n "${KUBECONFIG:-}" ]]; then
    kubeconfig_path="${KUBECONFIG%%:*}"
  else
    kubeconfig_path="${HOME}/.kube/config"
  fi
fi

if [[ ! -f "$kubeconfig_path" ]]; then
  echo "Error: kubeconfig file '$kubeconfig_path' does not exist." >&2
  exit 1
fi

if $create_gitlab_pat; then
  create_gitlab_registry_credentials
else
  registry_user="$(prompt_if_empty "Registry username" "$registry_user")"
  registry_token="$(prompt_if_empty_secret "Registry token" "$registry_token")"
fi

if ! gh auth status >/dev/null 2>&1; then
  if $non_interactive; then
    echo "Error: gh is not authenticated. Run 'gh auth login' first." >&2
    exit 1
  fi
  gh auth login --web --git-protocol https
fi

kubeconfig_b64="$(base64 < "$kubeconfig_path" | tr -d '\n')"

printf '%s' "$kubeconfig_b64" | gh secret set KUBECONFIG_B64 --repo "$repo"
printf '%s' "$registry_user" | gh secret set REGISTRY_USER --repo "$repo"
printf '%s' "$registry_token" | gh secret set REGISTRY_TOKEN --repo "$repo"

printf 'Configured GitHub Actions secrets for %s:\n' "$repo"
printf '  - KUBECONFIG_B64\n'
printf '  - REGISTRY_USER\n'
printf '  - REGISTRY_TOKEN\n'
if [[ -n "$gitlab_created_credential_kind" ]]; then
  printf 'GitLab registry credential source: %s\n' "$gitlab_created_credential_kind"
fi
