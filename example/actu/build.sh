#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

"${REPO_ROOT}/scripts/build-cpp-example.sh" \
    "${SCRIPT_DIR}/actu_throughput.cpp" \
    "${EDGE_ACTU_OUT:-${SCRIPT_DIR}/build}" \
    actu_throughput
