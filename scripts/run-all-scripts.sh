#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/hello-world.sh"
"${script_dir}/configmap.sh"
"${script_dir}/web-server.sh"
"${script_dir}/network-policy.sh"
"${script_dir}/flask-redis.sh"
"${script_dir}/flask-redis-netshield.sh"
"${script_dir}/java-args-env-file.sh"
