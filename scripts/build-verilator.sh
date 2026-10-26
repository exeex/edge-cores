#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}"
OBJ_DIR="${OUT_DIR}/obj"
VERILATOR_BIN="${VERILATOR:-verilator}"
PUBLIC_FILELIST="${OUT_DIR}/edge_e3_public.fl"
SIM_EXE="${OBJ_DIR}/Vedge_soc_demo_tb"

if ! command -v "${VERILATOR_BIN}" >/dev/null 2>&1; then
    echo "error: Verilator not found: ${VERILATOR_BIN}" >&2
    exit 1
fi

required=(
    "${REPO_ROOT}/src/soc/logical/tb/edge_soc_demo_tb.v"
    "${REPO_ROOT}/src/soc/logical/common/edge_soc_top.v"
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_interconnect.v"
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_err.v"
    "${REPO_ROOT}/src/soc/logical/mem/edge_axi_ram.v"
)
for path in "${required[@]}"; do
    if [[ ! -f "${path}" ]]; then
        echo "error: required Verilator input is missing: ${path}" >&2
        exit 1
    fi
done

# Resolve only public RTL and local SRAM models, never private test sources.
python3 "${REPO_ROOT}/tools/prepare_e3_filelist.py" --output "${PUBLIC_FILELIST}"

mkdir -p "${OUT_DIR}"
rm -rf "${OBJ_DIR}"

cd "${REPO_ROOT}"
"${VERILATOR_BIN}" \
    --binary \
    --timing \
    -Wno-fatal \
    --converge-limit 100000 \
    --top-module edge_soc_demo_tb \
    -DVERILATOR_SIM \
    -DIVERILOG_SIM \
    -DEDGE_DEBUG \
    -DEDGE_SCALAR_PIPE_EBREAK_REPORT_ONLY \
    -DEDGE_SCALAR_LSU_QUEUE_DEPTH=4 \
    -DEDGE_SCALAR_LOAD_QUEUE_DEPTH=2 \
    -I"${REPO_ROOT}/src/edge-32/rtl" \
    -Mdir "${OBJ_DIR}" \
    "${REPO_ROOT}/src/soc/logical/tb/edge_soc_demo_tb.v" \
    "${REPO_ROOT}/src/soc/logical/common/edge_soc_top.v" \
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_interconnect.v" \
    "${REPO_ROOT}/src/soc/logical/mem/edge_axi_ram.v" \
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_err.v" \
    -f "${PUBLIC_FILELIST}"

echo "Built ${SIM_EXE}"
