#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 <source.cpp> <output-dir> <name>" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUT_DIR="$2"
NAME="$3"
PYTHON="${PYTHON:-python3}"

resolve_llvm_tool() {
    local explicit="$1"
    local name="$2"
    local candidate
    if [[ -n "${explicit}" ]]; then
        printf '%s\n' "${explicit}"
        return
    fi
    if candidate="$(command -v "${name}" 2>/dev/null)"; then
        printf '%s\n' "${candidate}"
        return
    fi
    for candidate in "/opt/homebrew/opt/llvm/bin/${name}" "/opt/homebrew/opt/lld/bin/${name}"; do
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return
        fi
    done
    candidate="$(compgen -G "/usr/bin/${name}-[0-9]*" | sort -V | tail -n 1 || true)"
    if [[ -n "${candidate}" ]]; then
        printf '%s\n' "${candidate}"
        return
    fi
    return 1
}

CLANG="$(resolve_llvm_tool "${CLANG:-}" clang)" || { echo "error: required LLVM tool is missing: clang" >&2; exit 1; }
CLANGXX="$(resolve_llvm_tool "${CLANGXX:-}" clang++)" || { echo "error: required LLVM tool is missing: clang++" >&2; exit 1; }
LLVM_OBJDUMP="$(resolve_llvm_tool "${LLVM_OBJDUMP:-}" llvm-objdump || true)"
LLD="$(resolve_llvm_tool "${LLD:-}" ld.lld)" || { echo "error: required LLVM tool is missing: ld.lld" >&2; exit 1; }

for tool in "${CLANG}" "${CLANGXX}" "${LLD}"; do
    if [[ ! -x "${tool}" ]]; then
        echo "error: required LLVM tool is missing: ${tool}" >&2
        exit 1
    fi
done

mkdir -p "${OUT_DIR}"
target_flags=(
    --target=riscv64-unknown-elf
    -march=rv64imfd_zba
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
    -c "${SOURCE}" \
    -o "${OUT_DIR}/${NAME}.o"

"${CLANG}" "${target_flags[@]}" \
    -fuse-ld=lld -B"$(dirname "${LLD}")" \
    -nostdlib -nostartfiles \
    -Wl,-T,"${REPO_ROOT}/cpp/baremetal/linker.ld" \
    -Wl,-Map,"${OUT_DIR}/${NAME}.map" \
    "${OUT_DIR}/crt0.o" "${OUT_DIR}/${NAME}.o" \
    -o "${OUT_DIR}/${NAME}.elf"

if [[ -x "${LLVM_OBJDUMP}" ]]; then
    "${LLVM_OBJDUMP}" -d --no-show-raw-insn \
        "${OUT_DIR}/${NAME}.elf" > "${OUT_DIR}/${NAME}.objdump"
fi

"${PYTHON}" "${REPO_ROOT}/tools/elf2mem128.py" \
    "${OUT_DIR}/${NAME}.elf" \
    -o "${OUT_DIR}/${NAME}.memh" \
    --words-file "${OUT_DIR}/${NAME}.words"

echo "Built ${OUT_DIR}/${NAME}.elf"
