#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/hello-world-cvm.sh"
"${script_dir}/configmap-cvm.sh"
"${script_dir}/web-server-cvm.sh"
