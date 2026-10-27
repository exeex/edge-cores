#!/usr/bin/env bash
# Connect the shared NNC compiler/runtime to this workspace's RTL harness.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NNC_ROOT="${REPO_ROOT}/src/edge-nnc"
VENV_DIR="${UV_PROJECT_ENVIRONMENT:-${REPO_ROOT}/.venv}"
if [[ "${VENV_DIR}" != /* ]]; then VENV_DIR="${REPO_ROOT}/${VENV_DIR}"; fi
PYTHON="${PYTHON:-${VENV_DIR}/bin/python}"
if [[ "${PYTHON}" == */* && "${PYTHON}" != /* ]]; then
    PYTHON="${PWD}/${PYTHON}"
fi
if ! command -v "${PYTHON}" >/dev/null 2>&1; then
    echo "error: Python environment missing; run ./scripts/setup-python.sh or set PYTHON" >&2
    exit 1
fi
SIM_EXE="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}/obj/Vedge_soc_demo_tb"

if [[ ! -f "${NNC_ROOT}/nnc/run_smoke.py" ]]; then
    echo "error: initialize NNC: git submodule update --init src/edge-nnc" >&2
    exit 1
fi

# Check metadata without importing torch, so saved-artifact replay stays lightweight.
"${PYTHON}" - "${NNC_ROOT}" <<'PY'
import json
import sys
from importlib.metadata import PackageNotFoundError, distribution
from pathlib import Path
from urllib.parse import unquote, urlparse

try:
    distribution("torch")
    origin = json.loads(distribution("edge-nnc").read_text("direct_url.json") or "{}")
except PackageNotFoundError:
    raise SystemExit("error: selected Python needs PyTorch and editable NNC; run ./scripts/setup-python.sh")
checkout = Path(sys.argv[1]).resolve()
source = Path(unquote(urlparse(origin.get("url", "")).path)).resolve()
if not origin.get("dir_info", {}).get("editable") or source != checkout:
    raise SystemExit(f"error: selected Python needs editable NNC from {checkout}; run ./scripts/setup-python.sh")
PY

mode="${1:?expected unit, smoke or harness}"
shift
common=(--edge32-include "${REPO_ROOT}/src/edge-32/include"
        --e3-include "${REPO_ROOT}/src/edge-e3/include"
        --sim-exe "${SIM_EXE}"
        --sim-build-script "${REPO_ROOT}/scripts/build-verilator.sh")
case "${mode}" in
    unit)
        cd "${NNC_ROOT}"
        exec "${PYTHON}" -m unittest discover -s nnc -p 'test_*.py' "$@"
        ;;
    smoke)
        model="${REPO_ROOT}/example/llama/model.py"
        args=("$@")
        for ((i=0; i<${#args[@]}; i++)); do
            case "${args[i]}" in
                --model-file) model="${args[i+1]}" ;;
                --model-file=*) model="${args[i]#*=}" ;;
            esac
        done
        name="$(basename "${model}" .py)"
        exec "${PYTHON}" "${NNC_ROOT}/nnc/run_smoke.py" "${common[@]}" \
            --model-file "${model}" \
            --build-dir "${REPO_ROOT}/example/llama/build/${name}" "$@"
        ;;
    harness)
        exec "${PYTHON}" "${NNC_ROOT}/nnc/run_harness.py" "${common[@]}" \
            --out-dir "${NNC_ROOT}/example/llama/build/harness" "$@"
        ;;
    *) echo "error: unknown NNC mode: ${mode}" >&2; exit 2 ;;
esac
