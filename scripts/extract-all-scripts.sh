#!/usr/bin/env bash

set -euo pipefail

# Array of input/output file pairs
files=(
  "hello-world/README.md scripts/hello-world.sh"
  "configmap/README.md scripts/configmap.sh"
  "web-server/README.md scripts/web-server.sh"
  "network-policy/README.md scripts/network-policy.sh"
  "flask-redis/README.md scripts/flask-redis.sh"
  "flask-redis-netshield/README.md scripts/flask-redis-netshield.sh"
)

cvm_files=(
  "hello-world/README-CVM.md scripts/hello-world-cvm.sh"
  "configmap/README-CVM.md scripts/configmap-cvm.sh"
  "web-server/README-CVM.md scripts/web-server-cvm.sh"
)

generated_scripts=()
generated_cvm_scripts=()

# Loop over the file pairs
for pair in "${files[@]}"; do
  read -r input_file output_file <<<"$pair"
  ./scripts/extract-bash.sh "$input_file" "$output_file"
  docs_output_file="docs/$(basename "$output_file")"
  ./scripts/extract-bash.sh --docs-pe "$input_file" "$docs_output_file"
  generated_scripts+=("$output_file")
done

for pair in "${cvm_files[@]}"; do
  read -r input_file output_file <<<"$pair"
  ./scripts/extract-bash.sh "$input_file" "$output_file"
  docs_output_file="docs/$(basename "$output_file")"
  ./scripts/extract-bash.sh --docs-pe "$input_file" "$docs_output_file"
  generated_cvm_scripts+=("$output_file")
done

workshop_files=(
  "workshop/TDX-DEMO.md scripts/workshop.sh"
)

for pair in "${workshop_files[@]}"; do
  read -r input_file output_file <<<"$pair"
  ./scripts/extract-bash.sh "$input_file" "$output_file"
done

run_all_script="scripts/run-all-scripts.sh"
{
  echo '#!/usr/bin/env bash'
  echo
  echo 'set -euo pipefail'
  echo
  echo 'script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
  echo
  for script_path in "${generated_scripts[@]}"; do
    script_name="$(basename "$script_path")"
    echo "\"\${script_dir}/${script_name}\""
  done
} >"$run_all_script"

chmod +x "$run_all_script"

run_all_cvm_script="scripts/run-all-cvm-scripts.sh"
{
  echo '#!/usr/bin/env bash'
  echo
  echo 'set -euo pipefail'
  echo
  echo 'script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
  echo
  for script_path in "${generated_cvm_scripts[@]}"; do
    script_name="$(basename "$script_path")"
    echo "\"\${script_dir}/${script_name}\""
  done
} >"$run_all_cvm_script"

chmod +x "$run_all_cvm_script"
