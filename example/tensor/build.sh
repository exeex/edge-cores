#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${EDGE_TENSOR_OUT:-${SCRIPT_DIR}/build}"
LLVM_PREFIX="${LLVM_PREFIX:-/opt/homebrew/opt/llvm}"
LLD_PREFIX="${LLD_PREFIX:-/opt/homebrew/opt/lld}"
CLANG="${CLANG:-${LLVM_PREFIX}/bin/clang}"
CLANGXX="${CLANGXX:-${LLVM_PREFIX}/bin/clang++}"
LLVM_OBJDUMP="${LLVM_OBJDUMP:-${LLVM_PREFIX}/bin/llvm-objdump}"
LLD="${LLD:-${LLD_PREFIX}/bin/ld.lld}"
NAME="matmul64x64_128tokens_tiled_circular"

for tool in "${CLANG}" "${CLANGXX}" "${LLD}"; do
    if [[ ! -x "${tool}" ]]; then
        echo "error: required LLVM tool is missing: ${tool}" >&2
        exit 1
    fi
done

mkdir -p "${OUT_DIR}"
target_flags=(
    --target=riscv64-unknown-elf
    -march=rv64im_zba
    -mabi=lp64
    -mcmodel=medany
)

"${CLANG}" "${target_flags[@]}" \
    -c "${REPO_ROOT}/cpp/baremetal/crt0.s" \
    -o "${OUT_DIR}/crt0.o"

"${CLANGXX}" "${target_flags[@]}" \
    -x c++ -std=c++17 -ffreestanding -fno-builtin \
    -fno-exceptions -fno-rtti -fno-pic -fno-pie -O2 \
    -I"${REPO_ROOT}/cpp" \
    -c "${SCRIPT_DIR}/${NAME}.cpp" \
    -o "${OUT_DIR}/${NAME}.o"

"${CLANG}" "${target_flags[@]}" \
    -fuse-ld=lld -B"$(dirname "${LLD}")" \
    -nostdlib -nostartfiles \
    -Wl,-T,"${REPO_ROOT}/cpp/baremetal/linker.ld" \
    -Wl,-Map,"${OUT_DIR}/${NAME}.map" \
    "${OUT_DIR}/crt0.o" \
    "${OUT_DIR}/${NAME}.o" \
    -o "${OUT_DIR}/${NAME}.elf"

if [[ -x "${LLVM_OBJDUMP}" ]]; then
    "${LLVM_OBJDUMP}" -d --no-show-raw-insn \
        "${OUT_DIR}/${NAME}.elf" > "${OUT_DIR}/${NAME}.objdump"
fi

python3 "${REPO_ROOT}/tools/elf2mem128.py" \
    "${OUT_DIR}/${NAME}.elf" \
    -o "${OUT_DIR}/${NAME}.memh" \
    --words-file "${OUT_DIR}/${NAME}.words"

echo "Built ${OUT_DIR}/${NAME}.elf"
