#!/usr/bin/env bash

set -euo pipefail

show_help() {
  cat <<USAGE
Usage: $0 [OPTIONS] <markdown-file> [output-script]

Extracts all \`\`\`bash or \`\`\`sh code blocks from a Markdown file
and writes them as a standalone executable shell script.

Modes:
  default     Emits colored markdown + code, then executes code blocks.
  --docs-pe   Emits a demo-style script where each code line runs via pe 'COMMAND'.

Options:
  --docs-pe    Generate a docs runner script that uses pe for each code line.
  -y           Overwrite an existing output script without confirmation.
  --help       Show this help message and exit.

Examples:
  $0 doc.md
  $0 doc.md script.sh
  $0 --docs-pe doc.md docs/script.sh
USAGE
}

mode="default"
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
    --docs-pe)
      mode="docs-pe"
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
      break
      ;;
  esac
done

if [[ $# -lt 1 || $# -gt 2 ]]; then
  show_help >&2
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: File '$INPUT_FILE' not found." >&2
  exit 1
fi

TMP_OUTPUT=$(mktemp)
trap 'rm -f "$TMP_OUTPUT"' EXIT

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

write_generated_help() {
  local output_file="$1"
  local source_file="$2"
  local script_mode="$3"
  local description

  if [[ "$script_mode" == "docs-pe" ]]; then
    description="Runs a demo-style shell script generated from ${source_file}."
  else
    description="Runs shell commands extracted from ${source_file}."
  fi

  {
    echo 'show_help() {'
    echo '  cat <<USAGE'
    echo 'Usage: $0 [--help]'
    echo
    echo "$description"
    echo
    echo 'Options:'
    echo '  --help  Show this help message and exit.'
    echo 'USAGE'
    echo '}'
    echo
    echo 'while [[ $# -gt 0 ]]; do'
    echo '  case "$1" in'
    echo '    --help)'
    echo '      show_help'
    echo '      exit 0'
    echo '      ;;'
    echo '    --)'
    echo '      shift'
    echo '      break'
    echo '      ;;'
    echo '    -*)'
    echo '      echo "Error: Unknown option '\''$1'\''." >&2'
    echo '      show_help >&2'
    echo '      exit 1'
    echo '      ;;'
    echo '    *)'
    echo '      echo "Error: This script does not accept positional arguments." >&2'
    echo '      show_help >&2'
    echo '      exit 1'
    echo '      ;;'
    echo '  esac'
    echo 'done'
    echo
    echo 'if [[ $# -gt 0 ]]; then'
    echo '  echo "Error: This script does not accept positional arguments." >&2'
    echo '  show_help >&2'
    echo '  exit 1'
    echo 'fi'
    echo
  } >>"$output_file"
}

write_default_header() {
  {
    echo "#!/usr/bin/env bash"
    echo "# Generated file. Do not edit manually."
    echo
    echo "set -euo pipefail"
    echo
    echo "VIOLET='\\033[38;5;141m'"
    echo "ORANGE='\\033[38;5;208m'"
    echo "RESET='\\033[0m'"
    echo 'CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:---force}"'
    echo
  } >>"$TMP_OUTPUT"

  write_generated_help "$TMP_OUTPUT" "$INPUT_FILE" "default"
}

write_docs_header() {
  cat >>"$TMP_OUTPUT" <<'EOF'
#!/usr/bin/env bash
# Generated file. Do not edit manually.

set -Eeuo pipefail

TYPE_SPEED="${TYPE_SPEED:-25}"
PAUSE_AFTER_CMD="${PAUSE_AFTER_CMD:-0.6}"
SHELLRC="${SHELLRC:-/dev/null}"
PROMPT="${PROMPT:-$'\[\e[1;32m\]demo\[\e[0m\]:\[\e[1;34m\]~\[\e[0m\]\$ '}"
COLUMNS="${COLUMNS:-100}"
LINES="${LINES:-26}"
ORANGE="${ORANGE:-\033[38;5;208m}"
LILAC="${LILAC:-\033[38;5;141m}"
RESET="${RESET:-\033[0m}"
CONFIRM_ALL_ENVIRONMENT_VARIABLES="${CONFIRM_ALL_ENVIRONMENT_VARIABLES:-}"

slow_type() {
  local text="$*"
  local delay
  delay=$(awk "BEGIN { print 1 / $TYPE_SPEED }")
  for ((i=0; i<${#text}; i++)); do
    printf "%s" "${text:i:1}"
    sleep "$delay"
  done
}

pe() {
  local cmd="$*"
  printf "%b" "$ORANGE"
  slow_type "$cmd"
  printf "%b" "$RESET"
  printf "\n"

  if [[ -n "${PE_BUFFER:-}" ]]; then
    PE_BUFFER+=$'\n'
  fi
  PE_BUFFER+="$cmd"

  # Execute only when buffered lines form a complete shell command.
  if bash -n <(printf '%s\n' "$PE_BUFFER") 2>/dev/null; then
    eval "$PE_BUFFER"
    PE_BUFFER=""
  fi

  sleep "$PAUSE_AFTER_CMD"
}

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export COLUMNS LINES
export PS1="$PROMPT"
stty cols "$COLUMNS" rows "$LINES"

EOF

  write_generated_help "$TMP_OUTPUT" "$INPUT_FILE" "docs-pe"
}

escape_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

emit_printf_lines() {
  local output_file="$1"
  shift
  local line
  local escaped
  for line in "$@"; do
    escaped=$(escape_single_quotes "$line")
    echo "printf '%s\\n' '$escaped'" >>"$output_file"
  done
}

ends_with_continuation_backslash() {
  local line="$1"
  local trimmed="$line"
  local slash_count=0

  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  while [[ "$trimmed" == *\\ ]]; do
    slash_count=$((slash_count + 1))
    trimmed="${trimmed%\\}"
  done

  (( slash_count % 2 == 1 ))
}

emit_docs_pe_command() {
  local output_file="$1"
  shift
  local cmd_lines=("$@")

  echo 'pe "$(cat <<'"'"'EOF'"'"'' >>"$output_file"
  for line in "${cmd_lines[@]}"; do
    echo "$line" >>"$output_file"
  done
  echo 'EOF' >>"$output_file"
  echo ')"' >>"$output_file"
}

if [[ "$mode" == "docs-pe" ]]; then
  write_docs_header
else
  write_default_header
fi

in_block=false
code_block=false
markdown_buffer=()
code_buffer=()

flush_markdown() {
  if [[ ${#markdown_buffer[@]} -gt 0 ]]; then
    if [[ "$mode" == "docs-pe" ]]; then
      echo 'printf "%b" "$LILAC"' >> "$TMP_OUTPUT"
      emit_printf_lines "$TMP_OUTPUT" "${markdown_buffer[@]}"
      echo 'printf "%b" "$RESET"' >> "$TMP_OUTPUT"
      echo "" >> "$TMP_OUTPUT"
      markdown_buffer=()
      return
    fi

    echo 'printf "${VIOLET}"' >> "$TMP_OUTPUT"
    emit_printf_lines "$TMP_OUTPUT" "${markdown_buffer[@]}"
    echo 'printf "${RESET}"' >> "$TMP_OUTPUT"
    echo "" >> "$TMP_OUTPUT"
    markdown_buffer=()
  fi
}

flush_code_block() {
  if [[ ${#code_buffer[@]} -eq 0 ]]; then
    return
  fi

  if [[ "$mode" == "docs-pe" ]]; then
    current_command=()
    for line in "${code_buffer[@]}"; do
      current_command+=("$line")
      if ends_with_continuation_backslash "$line"; then
        continue
      fi
      emit_docs_pe_command "$TMP_OUTPUT" "${current_command[@]}"
      current_command=()
    done
    if [[ ${#current_command[@]} -gt 0 ]]; then
      emit_docs_pe_command "$TMP_OUTPUT" "${current_command[@]}"
    fi
    echo "" >> "$TMP_OUTPUT"
    code_buffer=()
    return
  fi

  echo 'printf "${ORANGE}"' >> "$TMP_OUTPUT"
  emit_printf_lines "$TMP_OUTPUT" "${code_buffer[@]}"
  echo 'printf "${RESET}"' >> "$TMP_OUTPUT"
  echo "" >> "$TMP_OUTPUT"
  for line in "${code_buffer[@]}"; do
    echo "$line" >> "$TMP_OUTPUT"
  done
  echo "" >> "$TMP_OUTPUT"
  code_buffer=()
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^\s*\`\`\`(bash|sh)\s*$ ]]; then
    flush_markdown
    in_block=true
    code_block=true
    continue
  elif [[ "$line" =~ ^\s*\`\`\` ]]; then
    if $in_block && $code_block; then
      flush_code_block
    fi
    in_block=false
    code_block=false
    continue
  fi

  if $in_block && $code_block; then
    code_buffer+=("$line")
  elif ! $in_block; then
    markdown_buffer+=("$line")
  fi
done < "$INPUT_FILE"

flush_markdown
flush_code_block

if [[ -n "$OUTPUT_FILE" ]]; then
  confirm_overwrite "$OUTPUT_FILE"
  command mv -f "$TMP_OUTPUT" "$OUTPUT_FILE"
  chmod 0555 "$OUTPUT_FILE"
  echo "✅ Script written to '$OUTPUT_FILE', made executable, and set read-only."
else
  cat "$TMP_OUTPUT"
fi

trap - EXIT
