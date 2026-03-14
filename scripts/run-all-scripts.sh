#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected_workdir="$(cd "${script_dir}/.." && pwd)"
expected_invocation="./$(basename "${script_dir}")/$(basename "$0")"

if [[ "$(pwd)" != "$expected_workdir" ]]; then
  echo "Error: Wrong working directory." >&2
  echo "Expected working directory: $expected_workdir" >&2
  echo "Run this script as: $expected_invocation" >&2
  exit 1
fi

script_args=("--non-interactive")

show_help() {
  cat <<USAGE
Usage: $0 [--help]

Runs every generated demo script in non-interactive mode.

Options:
  --help  Show this help message and exit.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -z "${SIGNER:-}" ]]; then
  export SIGNER="$(scone self show-session-signing-key)"
fi

current_script=""

run_script() {
  local script_name="$1"
  current_script="$script_name"
  printf "==> Running %s\n" "$script_name"
  "${script_dir}/${script_name}" "${script_args[@]}"
}

handle_exit() {
  local exit_status=$?
  if [[ $exit_status -ne 0 && -n "$current_script" ]]; then
    printf "Error: Script failed: %s\n" "$current_script" >&2
  fi
  trap - EXIT
  exit "$exit_status"
}

trap handle_exit EXIT

run_script "hello-world.sh"
run_script "configmap.sh"
run_script "web-server.sh"
run_script "network-policy.sh"
run_script "flask-redis.sh"
run_script "flask-redis-netshield.sh"
run_script "flask-redis-netshield.sh"
run_script "go-args-env-file.sh"
