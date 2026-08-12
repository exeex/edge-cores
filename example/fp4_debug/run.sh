#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_FP4_DEBUG_OUT:-${SCRIPT_DIR}/build}"
VERILATOR_OUT="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}"
SIM_EXE="${VERILATOR_OUT}/obj/Vedge_soc_demo_tb"
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

words="$(tr -d '[:space:]' < "${OUT_DIR}/fp4_debug.words")"
(
    cd "${OUT_DIR}"
    "${SIM_EXE}" \
        "+mem128=${OUT_DIR}/fp4_debug.memh" \
        "+mem128_words=${words}" \
        +max_cycles=40000 \
        +run_case_report=run_case.report
) 2>&1 | tee "${LOG}" | sed '/^- .*Verilog \$finish$/d'

grep -q "idx3=1.5 idx12=-3.0" "${LOG}"
grep -q "after 4/16 (incomplete, do not store): 0x09ab000000000000" "${LOG}"
grep -q "pack vs set: MATCH packed=0x432109ab432109ab" "${LOG}"
grep -q "stored bytes: ab 09 21 43 ab 09 21 43" "${LOG}"
grep -q "FP32 decoded: -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0 remaining=0x0000000000000000" "${LOG}"
grep -q "TEST PASS" "${REPORT}"
