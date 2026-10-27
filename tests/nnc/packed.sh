#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_PACKED_TEST_OUT:-${SCRIPT_DIR}/build/packed}"
SIM_EXE="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/verilator}/obj/Vedge_soc_demo_tb"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --skip-verilator-build ) ]]; then
    echo "usage: $0 [--skip-verilator-build]" >&2; exit 2
fi
mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
if [[ $# -eq 0 ]]; then
    "${REPO_ROOT}/scripts/build-verilator.sh" >"${OUT_DIR}/sim-build.log" 2>&1 || {
        cat "${OUT_DIR}/sim-build.log" >&2; exit 1;
    }
fi
printf 'case\tstatus\tlog\n' > "${OUT_DIR}/summary.tsv"
status=0
for name in packed weight_pack cache_ownership; do
    case_dir="${OUT_DIR}/${name}"
    mkdir -p "${case_dir}"
    source="${REPO_ROOT}/src/edge-nnc/nnc/test/packed_wsld_main.cpp"
    if [[ "${name}" == weight_pack ]]; then source="${REPO_ROOT}/src/edge-nnc/nnc/test/weight_pack_main.cpp"; fi
    if [[ "${name}" == cache_ownership ]]; then source="${REPO_ROOT}/src/edge-nnc/nnc/test/cache_ownership_main.cpp"; fi
    if ! "${REPO_ROOT}/scripts/build-cpp-example.sh" "${source}" "${case_dir}" "${name}" >"${case_dir}/build.log" 2>&1; then
        cat "${case_dir}/build.log" >&2; exit 1
    fi
    words="$(tr -d '[:space:]' < "${case_dir}/${name}.words")"
    rm -f "${case_dir}/run_case.report" "${case_dir}/run.log"
    result=PASS
    max_cycles=500000
    # All 26 configurations and their scalar goldens share one packed binary.
    # A K64 configuration alone takes about 540k cycles; budget the full set.
    if [[ "${name}" == packed ]]; then max_cycles=10000000; fi
    # Sixteen full Linear calls include scalar packing and nine-row goldens.
    if [[ "${name}" == weight_pack ]]; then max_cycles=30000000; fi
    if ! (
        cd "${case_dir}"
        "${SIM_EXE}" "+mem128=${case_dir}/${name}.memh" "+mem128_words=${words}" \
            +expected_return=0 "+max_cycles=${max_cycles}" +run_case_report=run_case.report
    ) >"${case_dir}/run.log" 2>&1; then result=FAIL; fi
    if ! grep -q 'TEST PASS' "${case_dir}/run_case.report"; then result=FAIL; fi
    if [[ "${name}" == packed ]] && ! grep -q 'PACKED ALL PASS cases=26' "${case_dir}/run.log"; then result=FAIL; fi
    if [[ "${name}" == weight_pack ]] && ! grep -q 'WEIGHT PACK ALL PASS cases=16' "${case_dir}/run.log"; then result=FAIL; fi
    if [[ "${name}" == cache_ownership ]] && ! grep -q 'CACHE OWNERSHIP PASS' "${case_dir}/run.log"; then result=FAIL; fi
    if [[ "${result}" == FAIL ]]; then status=1; cat "${case_dir}/run.log" >&2; fi
    printf '%s\t%s\t%s\n' "${name}" "${result}" "${case_dir}/run.log" | tee -a "${OUT_DIR}/summary.tsv"
done
exit "${status}"
