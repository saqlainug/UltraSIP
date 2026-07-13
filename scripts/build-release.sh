#!/usr/bin/env bash
# build-release.sh — canonical Release build, universal (arm64 + x86_64).
# Output: build/Release/MacSIP.app (ad-hoc signed unless sign.sh is run).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool xcodebuild "Install Xcode"
require_tool lipo "Ships with Xcode command line tools"

cd "${REPO_ROOT}"
log "Building MacSIP (Release, universal)..."
xcodebuild -project MacSIP.xcodeproj -scheme MacSIP -configuration Release \
  -derivedDataPath build/DerivedData \
  ONLY_ACTIVE_ARCH=NO ARCHS="arm64 x86_64" \
  build | tail -5

APP="build/DerivedData/Build/Products/Release/MacSIP.app"
[[ -d "${APP}" ]] || die "expected app bundle not found at ${APP}"
BIN="${APP}/Contents/MacOS/MacSIP"
log "Architectures: $(lipo -archs "${BIN}")"
lipo -archs "${BIN}" | grep -q "x86_64" || die "release binary is not universal (missing x86_64)"
lipo -archs "${BIN}" | grep -q "arm64" || die "release binary is not universal (missing arm64)"
log "Release universal build succeeded: ${APP}"
