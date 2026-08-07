#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOC="${REPO_ROOT}/third_party/openc906/smart_run"
RTL="${REPO_ROOT}/third_party/openc906/C906_RTL_FACTORY"
OUT="${C906_VERILATOR_OUT:-${REPO_ROOT}/build/c906-verilator}"
mkdir -p "${OUT}"
FILELIST="${OUT}/c906.fl"
{
  echo '+libext+.v+.h+.V+.sv+'
  echo "-f ${RTL}/gen_rtl/filelists/C906_asic_rtl.fl"
  echo "-f ${RTL}/gen_rtl/filelists/tdt_dmi_top_rtl.fl"
  for dir in ahb apb axi bus clk common gpio mem uart; do echo "-y ${SOC}/logical/${dir}"; done
  echo "+incdir+${SOC}/logical/tb+"
  echo "-y ${SOC}/logical/tb"
  echo "${SOC}/logical/tb/tb.v"
} > "${FILELIST}"
CODE_BASE_PATH="${RTL}" SOC_BASE_PATH="${SOC}" verilator --binary --compiler clang -Wno-fatal -Wno-BLKANDNBLK --timing --x-initial unique --top-module tb -DVERILATOR_SIM -DNO_DUMP -Dno_warning -DTSMC_NO_WARNING -f "${FILELIST}" -Mdir "${OUT}/obj"
