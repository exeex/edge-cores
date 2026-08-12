#!/usr/bin/env bash
set -euo pipefail

CHECK=()
if [[ "${1:-}" == "--check" ]]; then CHECK=(--check); shift; fi
PROFILE="${1:-}"
TARGET="${2:-xilinx}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

case "${PROFILE}" in
  edge-rv@e3) TOP=edge_core_top; FLIST=src/edge-e3enc/edge_e3enc_mixed.fl ;;
  edge-rv-lite@e3)
    TOP=edge_core_lite_top; FLIST=src/edge-e3enc/edge_e3enc_mixed.fl
    if ! rg -q '^module[[:space:]]+edge_core_lite_top([[:space:]#(]|$)' "${ROOT_DIR}/src/edge-e3enc/edge_e3enc.v"; then
      echo "error: profile '${PROFILE}' is predefined, but this edge-e3enc release does not export edge_core_lite_top" >&2
      echo "hint: regenerate/publish edge-e3enc with the rv-lite product top; do not fall back to src/edge-e3" >&2
      exit 2
    fi
    ;;
  edge-rv) TOP=edge_rv_top; FLIST=synth/filelists/edge_rv.fl ;;
  edge-rv-lite) TOP=edge_rv_lite_cached_core; FLIST=src/edge-rv-lite/filelists/edge_rv_lite.fl ;;
  *) echo "Usage: synth/run_profile.sh [--check] {edge-rv@e3|edge-rv-lite@e3|edge-rv|edge-rv-lite} [target]" >&2; exit 1 ;;
esac

export STAREDGE_YOSYS_VARIANT="${STAREDGE_YOSYS_VARIANT:-${PROFILE//@/-}}"
exec "${SCRIPT_DIR}/run_yosys.sh" "${CHECK[@]}" "${TOP}" "${TARGET}" "${FLIST}"
