#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_FORK_JOIN_OUT:-${SCRIPT_DIR}/build}"
export EDGE_VERILATOR_OUT="${EDGE_VERILATOR_OUT:-${REPO_ROOT}/build/architecture-trace}"
mkdir -p "${EDGE_VERILATOR_OUT}"
export EDGE_VERILATOR_OUT="$(cd "${EDGE_VERILATOR_OUT}" && pwd)"
SKIP_BUILD=0
PUBLISH=0
for arg in "$@"; do
    case "$arg" in
        --skip-verilator-build) SKIP_BUILD=1 ;;
        --publish-trace) PUBLISH=1 ;;
        *) echo "usage: $0 [--skip-verilator-build] [--publish-trace]" >&2; exit 2 ;;
    esac
done
mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
if [[ "${SKIP_BUILD}" == 0 ]]; then
    "${REPO_ROOT}/scripts/build-verilator.sh" >"${OUT_DIR}/simulator-build.log" 2>&1 || {
        tail -80 "${OUT_DIR}/simulator-build.log" >&2; exit 1;
    }
fi
"${SCRIPT_DIR}/build.sh" >"${OUT_DIR}/software-build.log" 2>&1 || {
    cat "${OUT_DIR}/software-build.log" >&2; exit 1;
}
words="$(tr -d '[:space:]' < "${OUT_DIR}/fork_join.words")"
rm -f "${OUT_DIR}/run_case.report" "${OUT_DIR}/trace.csv"
(
    cd "${OUT_DIR}"
    "${EDGE_VERILATOR_OUT}/obj/Vedge_soc_demo_tb" \
        "+mem128=${OUT_DIR}/fork_join.memh" "+mem128_words=${words}" \
        +max_cycles=1000000 +run_case_report=run_case.report \
        +arch_trace=trace.csv +arch_trace_command=32 +arch_trace_limit=200000
) 2>&1 | tee "${OUT_DIR}/run.log"
grep -q '^TEST PASS$' "${OUT_DIR}/run_case.report"
python3 "${REPO_ROOT}/tools/render_arch_trace.py" \
    --csv "${OUT_DIR}/trace.csv" --report "${OUT_DIR}/run_case.report" \
    --elf "${OUT_DIR}/fork_join.elf" --output "${OUT_DIR}/trace-data.js"
if [[ "${PUBLISH}" == 1 ]]; then
    cp "${OUT_DIR}/trace-data.js" "${REPO_ROOT}/docs/architecture-renderer/trace-data.js"
fi
