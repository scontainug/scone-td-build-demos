#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 [--help]

Removes SIGNER, REGISTRY_TOKEN, and REGISTRY_USER entries from every Values.yaml
file in this repository, including multi-line SIGNER block scalars.

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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
updated_count=0

process_file() {
  local file="$1"
  local tmp_file

  tmp_file="$(mktemp)"

  awk '
    function indent_len(line) {
      match(line, /^[ ]*/)
      return RLENGTH
    }

    BEGIN {
      skip_block = 0
      key_indent = -1
    }

    {
      if (skip_block) {
        if ($0 ~ /^[[:space:]]*$/) {
          next
        }

        if (indent_len($0) > key_indent) {
          next
        }

        skip_block = 0
      }

      if ($0 ~ /^[ ]*(SIGNER|REGISTRY_TOKEN|REGISTRY_USER):/) {
        key_indent = indent_len($0)
        if ($0 ~ /:[[:space:]]*\|[+-]?[[:space:]]*$/) {
          skip_block = 1
        }
        next
      }

      print
    }
  ' "$file" >"$tmp_file"

  if cmp -s "$file" "$tmp_file"; then
    rm -f "$tmp_file"
    return
  fi

  mv "$tmp_file" "$file"
  printf 'Updated %s\n' "${file#$repo_root/}"
  updated_count=$((updated_count + 1))
}

while IFS= read -r -d '' file; do
  process_file "$file"
done < <(find "$repo_root" -name 'Values.yaml' -print0 | sort -z)

if [[ $updated_count -eq 0 ]]; then
  printf 'No Values.yaml files needed changes.\n'
else
  printf 'Updated %d Values.yaml file(s).\n' "$updated_count"
fi
