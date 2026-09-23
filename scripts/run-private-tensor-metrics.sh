#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRIVATE_CORE="${REPO_ROOT}/src/edge-e3"
OUT_DIR="${EDGE_PRIVATE_TENSOR_METRICS_OUT:-${REPO_ROOT}/build/private-tensor-metrics}"
OBJ_DIR="${OUT_DIR}/obj"
TENSOR_OUT="${EDGE_TENSOR_OUT:-${REPO_ROOT}/example/tensor/build}"
VERILATOR_BIN="${VERILATOR:-verilator}"
SIM_EXE="${OBJ_DIR}/Vedge_soc_demo_tb"
MEMH="${TENSOR_OUT}/matmul64x64_128tokens_tiled_circular.memh"
WORDS_FILE="${TENSOR_OUT}/matmul64x64_128tokens_tiled_circular.words"
REPORT="${OUT_DIR}/run_case.report"
LOG="${OUT_DIR}/run.log"

if [[ ! -f "${PRIVATE_CORE}/edge_core/filelists/edge_core_edge32_top_verilator.fl" ]]; then
  echo "error: private edge-e3 submodule is not initialized" >&2
  exit 1
fi
if ! command -v "${VERILATOR_BIN}" >/dev/null 2>&1; then
  echo "error: Verilator not found: ${VERILATOR_BIN}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
rm -rf "${OBJ_DIR}"

(
  cd "${PRIVATE_CORE}"
  "${VERILATOR_BIN}" \
    --binary \
    --timing \
    -Wno-fatal \
    --converge-limit 100000 \
    --top-module edge_soc_demo_tb \
    -DVERILATOR_SIM \
    -DIVERILOG_SIM \
    -DEDGE_DEBUG \
    -DEDGE_PRIVATE_TENSOR_METRICS \
    -DEDGE_SCALAR_PIPE_EBREAK_REPORT_ONLY \
    -DEDGE_SCALAR_LSU_QUEUE_DEPTH=4 \
    -DEDGE_SCALAR_LOAD_QUEUE_DEPTH=2 \
    -I"${PRIVATE_CORE}/../edge-32/rtl" \
    -I"${PRIVATE_CORE}/../edge-asic/rtl" \
    -Mdir "${OBJ_DIR}" \
    "${REPO_ROOT}/src/soc/logical/tb/edge_soc_demo_tb.v" \
    "${REPO_ROOT}/src/soc/logical/common/edge_soc_top.v" \
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_interconnect.v" \
    "${REPO_ROOT}/src/soc/logical/mem/edge_axi_ram.v" \
    "${REPO_ROOT}/src/soc/logical/axi/edge_axi_err.v" \
    -f edge_core/filelists/edge_core_edge32_top_verilator.fl
)

EDGE_TENSOR_OUT="${TENSOR_OUT}" "${REPO_ROOT}/example/tensor/build.sh" \
  >"${OUT_DIR}/build-example.log" 2>&1

words="$(tr -d '[:space:]' < "${WORDS_FILE}")"
rm -f "${REPORT}" "${LOG}"
(
  cd "${OUT_DIR}"
  "${SIM_EXE}" \
    "+mem128=${MEMH}" \
    "+mem128_words=${words}" \
    +check_tensor_output \
    +pass_on_csr_break \
    +expected_return=0 \
    +max_cycles=500000 \
    +run_case_report=run_case.report
) 2>&1 | tee "${LOG}"

if [[ ! -f "${REPORT}" ]] || ! grep -q "TEST PASS" "${REPORT}"; then
  echo "error: private tensor metrics run did not pass; see ${LOG}" >&2
  exit 1
fi

awk -F= '
  /^TENSOR_ENGINE_COMPUTE_VALID_COUNT=/ { valid = $2 }
  /^TENSOR_ENGINE_COMPUTE_BUSY_COUNT=/ { busy = $2 }
  END {
    if (busy == 0) {
      print "tensor_mac_busy_utilization=unavailable"
    } else {
      printf "tensor_mac_busy_utilization=%.3f%% (%d/%d)\n", 100.0 * valid / busy, valid, busy
    }
  }
' "${REPORT}"

grep -E 'cycle_delta=|TENSOR_ENGINE_' "${LOG}" "${REPORT}" || true
