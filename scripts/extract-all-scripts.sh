#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 [-y]

Regenerates all extracted scripts and scripts/run-all-scripts.sh.

Options:
  -y    Overwrite existing generated scripts without confirmation.
  --help  Show this help message and exit.
USAGE
}

assume_yes=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y)
      assume_yes=true
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
    *)
      echo "Error: Unknown option '$1'." >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  show_help >&2
  exit 1
fi

# Array of input/output file pairs
files=(
  "hello-world/README.md scripts/hello-world.sh"
  "configmap/README.md scripts/configmap.sh"
  "web-server/README.md scripts/web-server.sh"
  "network-policy/README.md scripts/network-policy.sh"
  "flask-redis/README.md scripts/flask-redis.sh"
  "flask-redis-netshield/README.md scripts/flask-redis-netshield.sh"
  "flask-redis-netshield/README.md scripts/flask-redis-netshield.sh"
  "go-args-env-file/README.md scripts/go-args-env-file.sh"
)

generated_scripts=()
run_all_tmp="$(mktemp)"
trap 'rm -f "$run_all_tmp"' EXIT

confirm_overwrite() {
  local target="$1"
  local reply

  if $assume_yes || [[ ! -e "$target" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Error: Refusing to overwrite '$target' without confirmation. Re-run with -y." >&2
    exit 1
  fi

  read -r -p "Overwrite '$target'? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "Skipped '$target'."
    exit 0
  fi
}

# Loop over the file pairs
for pair in "${files[@]}"; do
  read -r input_file output_file <<<"$pair"
  if $assume_yes; then
    ./scripts/extract-bash.sh -y "$input_file" "$output_file"
  else
    ./scripts/extract-bash.sh "$input_file" "$output_file"
  fi
  docs_output_file="docs/$(basename "$output_file")"
  if $assume_yes; then
    ./scripts/extract-bash.sh -y --docs-pe "$input_file" "$docs_output_file"
  else
    ./scripts/extract-bash.sh --docs-pe "$input_file" "$docs_output_file"
  fi
  generated_scripts+=("$output_file")
done

run_all_script="scripts/run-all-scripts.sh"
{
  echo '#!/usr/bin/env bash'
  echo '# Generated file. Do not edit manually.'
  echo
  echo 'set -euo pipefail'
  echo
  echo 'script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
  echo
  for script_path in "${generated_scripts[@]}"; do
    script_name="$(basename "$script_path")"
    echo "\"\${script_dir}/${script_name}\""
  done
} >"$run_all_tmp"

confirm_overwrite "$run_all_script"
command mv -f "$run_all_tmp" "$run_all_script"
chmod 0555 "$run_all_script"
trap - EXIT
