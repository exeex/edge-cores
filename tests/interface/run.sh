#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_INTERFACE_OUT:-${SCRIPT_DIR}/build}"
SIM_EXE="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}/obj/Vedge_soc_demo_tb"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --skip-verilator-build ) ]]; then
    echo "usage: $0 [--skip-verilator-build]" >&2
    exit 2
fi
mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
"${PYTHON:-python3}" -m unittest discover -s "${SCRIPT_DIR}" -p 'test_*.py'
if [[ $# -eq 0 ]]; then
    "${REPO_ROOT}/scripts/build-verilator.sh" >"${OUT_DIR}/sim-build.log" 2>&1 || {
        cat "${OUT_DIR}/sim-build.log" >&2; exit 1;
    }
fi
"${REPO_ROOT}/scripts/build-cpp-example.sh" "${SCRIPT_DIR}/matmul.cpp" "${OUT_DIR}" matmul \
    >"${OUT_DIR}/build.log" 2>&1 || { cat "${OUT_DIR}/build.log" >&2; exit 1; }
words="$(tr -d '[:space:]' < "${OUT_DIR}/matmul.words")"
rm -f "${OUT_DIR}/run_case.report" "${OUT_DIR}/run.log"
(
    cd "${OUT_DIR}"
    "${SIM_EXE}" "+mem128=${OUT_DIR}/matmul.memh" "+mem128_words=${words}" \
        +expected_return=0 +max_cycles=5000000 +run_case_report=run_case.report
) 2>&1 | tee "${OUT_DIR}/run.log"
grep -q 'MATMUL_INTERFACE PASS cases=6' "${OUT_DIR}/run.log"
grep -q 'TEST PASS' "${OUT_DIR}/run_case.report"
