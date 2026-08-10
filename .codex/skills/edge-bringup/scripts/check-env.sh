#!/usr/bin/env bash
set -euo pipefail

missing=0
missing_uv=0
for tool in git cmake verilator python3 uv; do
    if command -v "${tool}" >/dev/null 2>&1; then
        printf '%-14s %s\n' "${tool}" "$(command -v "${tool}")"
    else
        printf '%-14s MISSING\n' "${tool}"
        missing=1
        [[ "${tool}" == uv ]] && missing_uv=1
    fi
done

resolve_llvm_tool() {
    local tool="$1"
    local found candidate
    found="$(command -v "${tool}" 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        printf '%s\n' "${found}"
        return
    fi
    for candidate in "/opt/homebrew/opt/llvm/bin/${tool}" "/opt/homebrew/opt/lld/bin/${tool}"; do
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return
        fi
    done
    compgen -G "/usr/bin/${tool}-[0-9]*" | sort -V | tail -n 1 || true
}

for tool in clang llvm-objdump llvm-objcopy ld.lld; do
    found="$(resolve_llvm_tool "${tool}")"
    if [[ -n "${found}" ]]; then
        printf '%-14s %s\n' "${tool}" "${found}"
    else
        printf '%-14s MISSING\n' "${tool}"
        missing=1
    fi
done

if (( missing )); then
    case "$(uname -s)" in
        Darwin) echo "install: brew install verilator llvm lld python cmake" ;;
        Linux) echo "install: sudo apt-get install -y build-essential git cmake verilator llvm clang lld python3 python3-venv" ;;
        *) echo "install: unsupported host; install Verilator, LLVM/Clang/LLD, CMake, Git, and Python 3" ;;
    esac
    if (( missing_uv )); then
        echo "install uv: https://docs.astral.sh/uv/getting-started/installation/"
    fi
fi

exit "${missing}"
