#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_TENSOR_OUT:-${SCRIPT_DIR}/build}"
VERILATOR_OUT="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}"
NAME="matmul64x64_128tokens_tiled_circular"
SIM_EXE="${VERILATOR_OUT}/obj/Vedge_soc_demo_tb"
MEMH="${OUT_DIR}/${NAME}.memh"
WORDS_FILE="${OUT_DIR}/${NAME}.words"
REPORT="${OUT_DIR}/run_case.report"
LOG="${OUT_DIR}/run.log"
BUILD_LOG="${OUT_DIR}/build.log"

mkdir -p "${OUT_DIR}"
if ! {
    "${REPO_ROOT}/scripts/build-verilator.sh" &&
    "${SCRIPT_DIR}/build.sh"
} >"${BUILD_LOG}" 2>&1; then
    cat "${BUILD_LOG}" >&2
    exit 1
fi

words="$(tr -d '[:space:]' < "${WORDS_FILE}")"
rm -f "${REPORT}" "${LOG}"

(
    cd "${OUT_DIR}"
    "${SIM_EXE}" \
        +verilator+quiet \
        "+mem128=${MEMH}" \
        "+mem128_words=${words}" \
        +check_tensor_output \
        +pass_on_csr_break \
        +expected_return=0 \
        +max_cycles=500000 \
        +run_case_report=run_case.report
) 2>&1 | tee "${LOG}" | sed '/^- .*Verilog \$finish$/d'

if [[ ! -f "${REPORT}" ]] || ! grep -q "TEST PASS" "${REPORT}"; then
    echo "error: tensor example did not pass; see ${LOG}" >&2
    exit 1
fi
