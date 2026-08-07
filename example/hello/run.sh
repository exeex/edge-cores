#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_HELLO_OUT:-${SCRIPT_DIR}/build}"
VERILATOR_OUT="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}"
SIM_EXE="${VERILATOR_OUT}/obj/Vedge_soc_demo_tb"
REPORT="${OUT_DIR}/run_case.report"
LOG="${OUT_DIR}/run.log"

"${REPO_ROOT}/scripts/build-verilator.sh"
"${SCRIPT_DIR}/build.sh"

words="$(tr -d '[:space:]' < "${OUT_DIR}/hello.words")"
(
    cd "${OUT_DIR}"
    "${SIM_EXE}" \
        "+mem128=${OUT_DIR}/hello.memh" \
        "+mem128_words=${words}" \
        +max_cycles=10000 \
        +run_case_report=run_case.report
) 2>&1 | tee "${LOG}"

grep -q "Hello from edge-e3!" "${LOG}"
grep -q "TEST PASS" "${REPORT}"
echo "Hello example passed: ${REPORT}"
