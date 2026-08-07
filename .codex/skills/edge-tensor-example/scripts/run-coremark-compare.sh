#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
echo '== C906 CoreMark =='
"${REPO_ROOT}/example/coremark/run-c906.sh"
echo '== Edge CoreMark =='
"${REPO_ROOT}/example/coremark/run-edge.sh"
