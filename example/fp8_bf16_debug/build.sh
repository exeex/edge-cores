#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

"${REPO_ROOT}/scripts/build-cpp-example.sh" \
    "${SCRIPT_DIR}/fp8_bf16_debug.cpp" \
    "${EDGE_FP8_BF16_DEBUG_OUT:-${SCRIPT_DIR}/build}" \
    fp8_bf16_debug
