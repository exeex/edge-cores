#!/usr/bin/env bash
# NNC owns test discovery, models, goldens and reports; this layer supplies RTL.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
status=0
"${REPO_ROOT}/scripts/run-nnc.sh" unit || status=1
"${REPO_ROOT}/scripts/run-nnc.sh" harness "$@" || status=1
exit "${status}"
