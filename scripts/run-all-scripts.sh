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
continue_on_failure=false
successful_scripts=()
failed_scripts=()
skipped_scripts=()
summary_printed=false

show_help() {
  cat <<USAGE
Usage: $0 [--help] [--continue-on-failure]

Runs every generated demo script in non-interactive mode.

Options:
  --help                   Show this help message and exit.
  --continue-on-failure    Continue with the next example after a failure.
  "--continue on failure"  Same as --continue-on-failure.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --continue-on-failure|'--continue on failure')
      continue_on_failure=true
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

if [[ -z "${SIGNER:-}" ]]; then
  export SIGNER="$(scone self show-session-signing-key)"
fi

print_script_list() {
  local heading="$1"
  shift
  printf "%s (%d):\n" "$heading" "$#"
  if [[ $# -eq 0 ]]; then
    printf "  - none\n"
    return
  fi
  for script_name in "$@"; do
    printf "  - %s\n" "$script_name"
  done
}

print_summary() {
  if $summary_printed; then
    return
  fi
  summary_printed=true
  printf "\n==> Execution summary\n"
  print_script_list "Successful" "${successful_scripts[@]}"
  print_script_list "Failed" "${failed_scripts[@]}"
  if [[ ${#skipped_scripts[@]} -gt 0 ]]; then
    print_script_list "Not run" "${skipped_scripts[@]}"
  fi
}

run_script() {
  local script_name="$1"
  local status
  printf "==> Running %s\n" "$script_name"
  if "${script_dir}/${script_name}" "${script_args[@]}"; then
    successful_scripts+=("$script_name")
    printf "==> Completed %s\n" "$script_name"
    return 0
  else
    status=$?
    failed_scripts+=("$script_name")
    printf "Error: Script failed: %s (exit %d)\n" "$script_name" "$status" >&2
    return "$status"
  fi
}

handle_exit() {
  local exit_status=$?
  print_summary
  trap - EXIT
  exit "$exit_status"
}

trap handle_exit EXIT

scripts=(
  "hello-world.sh"
  "configmap.sh"
  "web-server.sh"
  "network-policy.sh"
  "flask-redis.sh"
  "flask-redis-netshield.sh"
  "go-args-env-file.sh"
  "software-updates.sh"
)

for ((i = 0; i < ${#scripts[@]}; i++)); do
  script_name="${scripts[i]}"
  if run_script "$script_name"; then
    continue
  else
    status=$?
    if ! $continue_on_failure; then
      for ((j = i + 1; j < ${#scripts[@]}; j++)); do
        skipped_scripts+=("${scripts[j]}")
      done
      exit "$status"
    fi
    printf "==> Continuing with remaining scripts\n"
  fi
done

if [[ ${#failed_scripts[@]} -gt 0 ]]; then
  exit 1
fi
