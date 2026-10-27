#!/usr/bin/env bash
# Keep independent failure domains visible in the workspace regression.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
group="${1:-all}"
if [[ $# -gt 0 ]]; then shift; fi
case "${group}" in
    --list)
        printf '%s\n' \
            'nnc-unit: NNC-owned Python compiler and FP4 tests' \
            'nnc: NNC unit tests + all model smokes + Llama profile (workspace RTL adapter)' \
            'interface: standalone NNC matmul via libnn/ops.hpp against workspace intrinsics and public RTL' \
            'examples: hello, tensor, ACTU, scalar FP4/FP8 and named quant Linear examples' \
            'all: nnc + interface + examples' \
            'benchmark (separate): example/coremark/run-edge.sh and run-c906.sh'
        exit 0 ;;
    nnc-unit) exec "${REPO_ROOT}/scripts/run-nnc.sh" unit "$@" ;;
    nnc) exec "${SCRIPT_DIR}/nnc/run.sh" "$@" ;;
    interface) exec "${SCRIPT_DIR}/interface/run.sh" "$@" ;;
    examples|all) ;;
    *) echo "usage: $0 [--list|nnc-unit|nnc|interface|examples|all]" >&2; exit 2 ;;
esac
if [[ $# -ne 0 ]]; then echo "error: ${group} takes no additional arguments" >&2; exit 2; fi
OUT_DIR="${REPO_ROOT}/build/tests/${group}"
mkdir -p "${OUT_DIR}"
printf 'case\tstatus\tlog\n' > "${OUT_DIR}/summary.tsv"
status=0
run_case() {
    local name="$1"; shift
    local result=PASS
    echo "Running ${name}"
    "$@" >"${OUT_DIR}/${name}.log" 2>&1 || { result=FAIL; status=1; }
    printf '%s\t%s\t%s\n' "${name}" "${result}" "${OUT_DIR}/${name}.log" | tee -a "${OUT_DIR}/summary.tsv"
}
if [[ "${group}" == all ]]; then
    run_case nnc "${SCRIPT_DIR}/nnc/run.sh"
    run_case interface "${SCRIPT_DIR}/interface/run.sh"
fi
for name in hello tensor actu fp4_debug fp8_bf16_debug linear_fp4 linear_q8_0 linear_fp8_e4m3fn linear_fp8_e5m2; do
    run_case "${name}" "${REPO_ROOT}/example/${name}/run.sh"
done
echo "Report: ${OUT_DIR}/summary.tsv"
exit "${status}"
