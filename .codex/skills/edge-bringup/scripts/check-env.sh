#!/usr/bin/env bash
set -euo pipefail

missing=0
for tool in git cmake verilator python3; do
    if command -v "${tool}" >/dev/null 2>&1; then
        printf '%-14s %s\n' "${tool}" "$(command -v "${tool}")"
    else
        printf '%-14s MISSING\n' "${tool}"
        missing=1
    fi
done

for tool in clang llvm-objdump ld.lld; do
    found="$(command -v "${tool}" 2>/dev/null || true)"
    if [[ -z "${found}" && -x "/opt/homebrew/opt/llvm/bin/${tool}" ]]; then
        found="/opt/homebrew/opt/llvm/bin/${tool}"
    fi
    if [[ -z "${found}" && -x "/opt/homebrew/opt/lld/bin/${tool}" ]]; then
        found="/opt/homebrew/opt/lld/bin/${tool}"
    fi
    if [[ -n "${found}" ]]; then
        printf '%-14s %s\n' "${tool}" "${found}"
    else
        printf '%-14s MISSING\n' "${tool}"
        missing=1
    fi
done

case "$(uname -s)" in
    Darwin) echo "install: brew install verilator llvm lld python cmake" ;;
    Linux) echo "install: sudo apt-get install -y build-essential git cmake verilator llvm clang lld python3 python3-pip python3-venv" ;;
    *) echo "install: unsupported host; install Verilator, LLVM/Clang/LLD, CMake, Git, and Python 3" ;;
esac

exit "${missing}"
