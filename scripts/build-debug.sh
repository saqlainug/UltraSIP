#!/usr/bin/env bash
# build-debug.sh — canonical Debug build (xcodebuild).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool xcodebuild "Install Xcode"

cd "${REPO_ROOT}"
log "Building UltraSIP (Debug)..."
xcodebuild -project UltraSIP.xcodeproj -scheme UltraSIP -configuration Debug build \
  | tail -5
log "Debug build succeeded."
