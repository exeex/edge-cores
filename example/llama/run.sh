#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Keep the general smoke-model entry point available with isolated build output.
for arg in "$@"; do
    case "${arg}" in
        --model-file|--model-file=*) exec "${REPO_ROOT}/scripts/run-nnc.sh" smoke "$@" ;;
    esac
done
exec "${REPO_ROOT}/scripts/run-nnc.sh" smoke \
    --model-file "${SCRIPT_DIR}/model.py" \
    --main-file "${SCRIPT_DIR}/main.cpp" \
    --generated-dir "${SCRIPT_DIR}" \
    --build-dir "${SCRIPT_DIR}/build" "$@"
