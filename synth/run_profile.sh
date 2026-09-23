#!/usr/bin/env bash
set -euo pipefail

CHECK=()
if [[ "${1:-}" == "--check" ]]; then CHECK=(--check); shift; fi
PROFILE="${1:-}"
TARGET="${2:-xilinx}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

case "${PROFILE}" in
  edge32@e3) TOP=edge_core_edge32_top; FLIST=src/edge-e3enc/edge_e3enc_mixed.fl ;;
  edge-rv) TOP=edge_rv_top; FLIST=synth/filelists/edge_rv.fl ;;
  edge-rv-lite) TOP=edge_rv_lite_cached_core; FLIST=src/edge-rv-lite/filelists/edge_rv_lite.fl ;;
  *) echo "Usage: synth/run_profile.sh [--check] {edge32@e3|edge-rv|edge-rv-lite} [target]" >&2; exit 1 ;;
esac

export STAREDGE_YOSYS_VARIANT="${STAREDGE_YOSYS_VARIANT:-${PROFILE//@/-}}"
exec "${SCRIPT_DIR}/run_yosys.sh" "${CHECK[@]}" "${TOP}" "${TARGET}" "${FLIST}"
