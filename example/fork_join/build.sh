#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
"${REPO_ROOT}/scripts/build-cpp-example.sh" "${SCRIPT_DIR}/fork_join.cpp" \
    "${EDGE_FORK_JOIN_OUT:-${SCRIPT_DIR}/build}" fork_join
