#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT="${C906_COREMARK_OUT:-${SCRIPT_DIR}/build/c906}"
LLVM_PREFIX="${LLVM_PREFIX:-/opt/homebrew/opt/llvm}"
LLD_PREFIX="${LLD_PREFIX:-/opt/homebrew/opt/lld}"
mkdir -p "${OUT}"
flags=(--target=riscv64-unknown-elf -march=rv64imac_zicsr -mabi=lp64 -mcmodel=medany)
"${LLVM_PREFIX}/bin/clang" "${flags[@]}" -c "${SCRIPT_DIR}/c906_crt0.s" -o "${OUT}/crt0.o"
"${LLVM_PREFIX}/bin/clang" "${flags[@]}" -std=gnu11 -ffreestanding -fno-builtin -fno-pic -fno-pie -O2 -I"${SCRIPT_DIR}" -I"${REPO_ROOT}/third_party/coremark" -c "${SCRIPT_DIR}/coremark_bench.c" -o "${OUT}/coremark.o"
"${LLVM_PREFIX}/bin/clang" "${flags[@]}" -fuse-ld=lld -B"${LLD_PREFIX}/bin" -nostdlib -nostartfiles -Wl,-T,"${SCRIPT_DIR}/c906.ld" "${OUT}/crt0.o" "${OUT}/coremark.o" -o "${OUT}/coremark.elf"
python3 "${REPO_ROOT}/tools/elf2c906_pat.py" "${OUT}/coremark.elf" --inst-output "${OUT}/inst.pat" --data-output "${OUT}/data.pat"
