#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REQUESTED_BACKEND="${1:-${EDGE_TORCH_BACKEND:-auto}}"

usage() {
    echo "usage: $0 [auto|cpu|cu126|cu130|cu132]" >&2
    exit 2
}

select_auto_backend() {
    local gpu_info cuda_version major minor
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo "CPU setup: nvidia-smi was not found" >&2
        printf '%s\n' cpu
        return
    fi
    gpu_info="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || true)"
    if [[ -z "${gpu_info}" ]]; then
        echo "CPU setup: nvidia-smi could not query a GPU" >&2
        printf '%s\n' cpu
        return
    fi
    cuda_version="$(nvidia-smi 2>/dev/null | sed -nE 's/.*CUDA( UMD)? Version:[[:space:]]*([0-9]+\.[0-9]+).*/\2/p' | head -n 1)"
    if [[ -z "${cuda_version}" ]]; then
        echo "CPU setup: nvidia-smi did not report a CUDA version" >&2
        printf '%s\n' cpu
        return
    fi
    major="${cuda_version%%.*}"
    minor="${cuda_version#*.}"
    minor="${minor%%.*}"
    echo "NVIDIA GPU: ${gpu_info//$'\n'/, }" >&2
    echo "Driver-supported CUDA: ${cuda_version}" >&2
    if (( major > 13 || (major == 13 && minor >= 2) )); then
        printf '%s\n' cu132
    elif (( major == 13 )); then
        printf '%s\n' cu130
    elif (( major == 12 && minor >= 6 )); then
        printf '%s\n' cu126
    else
        echo "CPU setup: no maintained PyTorch CUDA wheel matches CUDA ${cuda_version}" >&2
        printf '%s\n' cpu
    fi
}

case "${REQUESTED_BACKEND}" in
    auto) BACKEND="$(select_auto_backend)" ;;
    cpu|cu126|cu130|cu132) BACKEND="${REQUESTED_BACKEND}" ;;
    *) usage ;;
esac

echo "PyTorch backend: ${BACKEND}"
cd "${REPO_ROOT}"
uv sync --extra "${BACKEND}"

VENV_DIR="${UV_PROJECT_ENVIRONMENT:-${REPO_ROOT}/.venv}"
if [[ "${VENV_DIR}" != /* ]]; then
    VENV_DIR="${REPO_ROOT}/${VENV_DIR}"
fi
"${VENV_DIR}/bin/python" - "${BACKEND}" <<'PY'
import sys
import torch

backend = sys.argv[1]
print(f"Python: {sys.executable}")
print(f"PyTorch: {torch.__version__}")
print(f"PyTorch CUDA: {torch.version.cuda}")
print(f"CUDA available: {torch.cuda.is_available()}")
if backend.startswith("cu"):
    if not torch.cuda.is_available():
        raise SystemExit(f"error: {backend} was selected but PyTorch cannot use CUDA")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
elif torch.version.cuda is not None:
    raise SystemExit("error: CPU backend selected but a CUDA PyTorch build was installed")
PY
