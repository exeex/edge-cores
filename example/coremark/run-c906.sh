#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT="${C906_COREMARK_OUT:-${SCRIPT_DIR}/build/c906}"
SIM_OUT="${C906_VERILATOR_OUT:-${REPO_ROOT}/build/c906-verilator}"
"${SCRIPT_DIR}/build-c906.sh"
[[ -x "${SIM_OUT}/obj/Vtb" ]] || "${SCRIPT_DIR}/build-c906-sim.sh"
rm -f "${OUT}/run_case.report" "${OUT}/run.log"
(cd "${OUT}" && "${SIM_OUT}/obj/Vtb") 2>&1 | tee "${OUT}/run.log"
grep -q 'TEST PASS' "${OUT}/run_case.report"
hex="$(sed -n 's/.*RETURN_VALUE 0x\([0-9a-fA-F]*\).*/\1/p' "${OUT}/run_case.report" | tail -1)"
[[ -n "${hex}" ]]
printf 'cycle_delta=%d\n' "$((16#${hex}))"
