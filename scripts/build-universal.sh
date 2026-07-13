#!/usr/bin/env bash
# build-universal.sh — full universal pipeline: reproducible PJSIP static
# libs (both arches) + Release universal app build, with lipo verification.
# Equivalent to: scripts/build-pjsip.sh && scripts/build-release.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root

"${SCRIPT_DIR}/build-pjsip.sh"
"${SCRIPT_DIR}/build-release.sh"
log "Universal pipeline complete."
