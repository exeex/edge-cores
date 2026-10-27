#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
exec "${REPO_ROOT}/scripts/run-nnc.sh" smoke \
    --artifacts-dir "${SCRIPT_DIR}" \
    --model-file "${SCRIPT_DIR}/model.py" \
    --main-file "${SCRIPT_DIR}/main.cpp" \
    --build-dir "${SCRIPT_DIR}/build" "$@"
