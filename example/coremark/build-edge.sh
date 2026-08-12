#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT="${EDGE_COREMARK_OUT:-${SCRIPT_DIR}/build/edge}"
LLVM_PREFIX="${LLVM_PREFIX:-/opt/homebrew/opt/llvm}"
LLD_PREFIX="${LLD_PREFIX:-/opt/homebrew/opt/lld}"
mkdir -p "${OUT}"
flags=(--target=riscv64-unknown-elf -march=rv64imfd_zba -mabi=lp64 -mcmodel=medany)
"${LLVM_PREFIX}/bin/clang" "${flags[@]}" -c "${REPO_ROOT}/cpp/baremetal/crt0.s" -o "${OUT}/crt0.o"
"${LLVM_PREFIX}/bin/clang" "${flags[@]}" -std=gnu11 -ffreestanding -fno-builtin -fno-pic -fno-pie -O2 -DSTAREDGE_BENCH_EDGE -I"${SCRIPT_DIR}" -I"${REPO_ROOT}/third_party/coremark" -c "${SCRIPT_DIR}/coremark_bench.c" -o "${OUT}/coremark.o"
"${LLVM_PREFIX}/bin/clang" "${flags[@]}" -fuse-ld=lld -B"${LLD_PREFIX}/bin" -nostdlib -nostartfiles -Wl,-T,"${REPO_ROOT}/cpp/baremetal/linker.ld" "${OUT}/crt0.o" "${OUT}/coremark.o" -o "${OUT}/coremark.elf"
python3 "${REPO_ROOT}/tools/elf2mem128.py" "${OUT}/coremark.elf" -o "${OUT}/coremark.memh" --words-file "${OUT}/coremark.words"
