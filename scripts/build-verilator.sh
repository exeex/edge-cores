#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}"
OBJ_DIR="${OUT_DIR}/obj"
VERILATOR_BIN="${VERILATOR:-verilator}"
CORE_RTL="${REPO_ROOT}/src/edge-e3enc/edge_e3enc.v"
SRAM_FILELIST="${REPO_ROOT}/src/edge-e3enc/edge_e3enc_sram.fl"
SIM_EXE="${OBJ_DIR}/Vedge_soc_demo_tb"

if ! command -v "${VERILATOR_BIN}" >/dev/null 2>&1; then
    echo "error: Verilator not found: ${VERILATOR_BIN}" >&2
    exit 1
fi

required=(
    "${CORE_RTL}"
    "${SRAM_FILELIST}"
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

while IFS= read -r relative_path; do
    [[ -z "${relative_path}" || "${relative_path}" == \#* ]] && continue
    if [[ ! -f "${REPO_ROOT}/${relative_path}" ]]; then
        echo "error: SRAM model is missing: ${REPO_ROOT}/${relative_path}" >&2
        echo "hint: initialize the private src/edge-e3 submodule or provide equivalent models" >&2
        exit 1
    fi
done < "${SRAM_FILELIST}"

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
    -Mdir "${OBJ_DIR}" \
    "${REPO_ROOT}/src/soc/logical/tb/edge_soc_demo_tb.v" \
    "${REPO_ROOT}/src/soc/logical/common/edge_soc_top.v" \
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_interconnect.v" \
    "${REPO_ROOT}/src/soc/logical/mem/edge_axi_ram.v" \
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_err.v" \
    "${CORE_RTL}" \
    -f "${SRAM_FILELIST}"

echo "Built ${SIM_EXE}"
