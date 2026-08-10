#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT="${EDGE_COREMARK_OUT:-${SCRIPT_DIR}/build/edge}"
VERILATOR_OUT="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}"
mkdir -p "${OUT}"
"${REPO_ROOT}/scripts/build-verilator.sh"
"${SCRIPT_DIR}/build-edge.sh"
words="$(tr -d '[:space:]' < "${OUT}/coremark.words")"
(cd "${OUT}" && "${VERILATOR_OUT}/obj/Vedge_soc_demo_tb" "+mem128=${OUT}/coremark.memh" "+mem128_words=${words}" +max_cycles=3000000 +run_case_report=run_case.report) 2>&1 | tee "${OUT}/run.log"
grep -q 'TEST PASS' "${OUT}/run_case.report"
grep -E 'cycle_delta=[0-9]+' "${OUT}/run.log" | tail -1
