#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: synth/run_yosys.sh [--check] <top> [target] [filelist]

target: generic | xilinx | ecp5 (default: xilinx)
EOF
}

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then CHECK_ONLY=1; shift; fi
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then usage; exit 0; fi

TOP="$1"
TARGET="${2:-xilinx}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EDGE_RV_ROOT="${EDGE_RV_ROOT:-${ROOT_DIR}/src/edge-rv}"
EDGE_RV_LITE_ROOT="${EDGE_RV_LITE_ROOT:-${ROOT_DIR}/src/edge-rv-lite}"
FLIST="${3:-${SCRIPT_DIR}/filelists/${TOP}.fl}"
VARIANT="${STAREDGE_YOSYS_VARIANT:-${TARGET}}"
read -r -a EXTRA_DEFINES <<< "${STAREDGE_YOSYS_DEFINES:-}"
XILINX_NODSP="${STAREDGE_YOSYS_XILINX_NODSP:-0}"

[[ -f "${FLIST}" ]] || { echo "error: filelist not found: ${FLIST}" >&2; exit 1; }
declare -a RTL_FILES=() INCLUDE_DIRS=()

expand_path() {
  local path="$1"
  path="${path//'${ROOT_DIR}'/${ROOT_DIR}}"
  path="${path//'${EDGE_RV_ROOT}'/${EDGE_RV_ROOT}}"
  path="${path//'${EDGE_RV_LITE_ROOT}'/${EDGE_RV_LITE_ROOT}}"
  [[ "${path}" == /* ]] || path="${ROOT_DIR}/${path}"
  printf '%s\n' "${path}"
}

read_filelist() {
  local flist="$1" raw line nested file yosys_file
  while IFS= read -r raw || [[ -n "${raw}" ]]; do
    line="${raw%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "${line}" ]] || continue
    case "${line}" in
      +incdir+*) INCLUDE_DIRS+=("$(expand_path "${line#+incdir+}")") ;;
      -f\ *) nested="$(expand_path "${line#-f }")"; [[ -f "${nested}" ]] || { echo "error: nested filelist not found: ${nested}" >&2; exit 1; }; read_filelist "${nested}" ;;
      -f*) nested="$(expand_path "${line#-f}")"; [[ -f "${nested}" ]] || { echo "error: nested filelist not found: ${nested}" >&2; exit 1; }; read_filelist "${nested}" ;;
      *.v|*.sv|*.V)
        file="$(expand_path "${line}")"
        if [[ "${TARGET}" == xilinx ]]; then
          yosys_file="${file%.v}_yosys.v"
          [[ -f "${yosys_file}" ]] && file="${yosys_file}"
        fi
        RTL_FILES+=("${file}"); INCLUDE_DIRS+=("$(dirname "${file}")") ;;
      *.h|*.vh) INCLUDE_DIRS+=("$(dirname "$(expand_path "${line}")")") ;;
      *) echo "warning: ignored filelist entry: ${line}" >&2 ;;
    esac
  done < "${flist}"
}

read_filelist "${FLIST}"
for file in "${RTL_FILES[@]}"; do [[ -f "${file}" ]] || { echo "error: source file not found: ${file}" >&2; exit 1; }; done
if [[ "${CHECK_ONLY}" == 1 ]]; then
  echo "OK: top=${TOP} target=${TARGET} sources=${#RTL_FILES[@]} filelist=${FLIST}"
  exit 0
fi
command -v yosys >/dev/null || { echo "error: yosys is not installed" >&2; exit 1; }

OUT_DIR="${SCRIPT_DIR}/build/${TOP}/${VARIANT}"
mkdir -p "${OUT_DIR}"
TCL="${OUT_DIR}/run.ys"; LOG="${OUT_DIR}/yosys.log"; STAT="${OUT_DIR}/stat.txt"
NETLIST="${OUT_DIR}/${TOP}_${TARGET}.v"; JSON="${OUT_DIR}/${TOP}_${TARGET}.json"
{
  printf 'read_verilog -sv -DSYNTHESIS -DEDGE_YOSYS_SYNTH'
  for define in "${EXTRA_DEFINES[@]}"; do printf ' -D%s' "${define}"; done
  while IFS= read -r dir; do printf ' -I%s' "${dir}"; done < <(printf '%s\n' "${INCLUDE_DIRS[@]}" | sort -u)
  printf ' -defer'; printf ' %s' "${RTL_FILES[@]}"; printf '\n'
  if [[ "${TARGET}" == xilinx ]]; then printf 'hierarchy -top %s\n' "${TOP}"; else printf 'hierarchy -check -top %s\n' "${TOP}"; fi
  case "${TARGET}" in
    generic) printf 'proc; opt; memory; opt; fsm; opt; techmap; opt; abc; clean\ntee -o %s stat\nwrite_verilog -noattr %s\n' "${STAT}" "${NETLIST}" ;;
    xilinx) [[ "${XILINX_NODSP}" == 1 ]] && nodsp=-nodsp || nodsp=; printf 'synth_xilinx -top %s -family xc7 -noiopad -noclkbuf %s\ntee -o %s stat\nwrite_json %s\nwrite_verilog -noattr %s\n' "${TOP}" "${nodsp}" "${STAT}" "${JSON}" "${NETLIST}" ;;
    ecp5) printf 'synth_ecp5 -top %s -json %s\ntee -o %s stat\nwrite_verilog -noattr %s\n' "${TOP}" "${JSON}" "${STAT}" "${NETLIST}" ;;
    *) echo "error: unknown target '${TARGET}'" >&2; exit 1 ;;
  esac
} > "${TCL}"
echo "Running Yosys: top=${TOP} target=${TARGET} filelist=${FLIST}"
yosys -l "${LOG}" "${TCL}"
echo "Report: ${STAT}"
