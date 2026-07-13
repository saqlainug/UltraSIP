#!/usr/bin/env bash
# bootstrap.sh — verify required tools, then fetch + checksum-verify the
# pinned PJSIP source archive (no build; run scripts/build-pjsip.sh next).
# Writes only inside ThirdParty/cache/.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root

log "Checking required tools..."
require_tool git "Install the Xcode command line tools: xcode-select --install"
require_tool xcodebuild "Install Xcode from the App Store or developer.apple.com"
require_tool swift "Ships with Xcode"
require_tool clang "Ships with Xcode"
require_tool curl "Ships with macOS"
require_tool shasum "Ships with macOS"
require_tool tar "Ships with macOS"
require_tool lipo "Ships with Xcode command line tools"
require_tool libtool "Ships with Xcode command line tools"

log "xcodebuild: $(xcodebuild -version | tr '\n' ' ')"
log "swift:      $(swift --version 2>&1 | head -1)"
log "macOS SDKs: $(xcodebuild -showsdks 2>/dev/null | grep -c macosx || true) macosx SDK(s) available"

if ! swift format --version >/dev/null 2>&1; then
  warn "swift format subcommand unavailable; scripts/lint.sh will fail. Expected in Swift 6+ toolchains."
fi

log "Fetching pinned PJSIP archive (checksum-verified)..."
"${SCRIPT_DIR}/build-pjsip.sh" --fetch-only

log "Bootstrap complete. Next: scripts/build-pjsip.sh && scripts/build-debug.sh && scripts/test.sh"
