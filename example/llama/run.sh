#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PYTHON="${PYTHON:-python3}"

exec "${PYTHON}" "${REPO_ROOT}/nnc/run_smoke.py" \
    --model-file "${SCRIPT_DIR}/model/llama3_source.py" "$@"
