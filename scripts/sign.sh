#!/usr/bin/env bash
# sign.sh — Developer ID signing with Hardened Runtime + entitlements.
# REQUIRES USER-HELD CREDENTIALS. Never run this without explicit user
# approval (CLAUDE.md). No credentials are read from the repository.
#
# Usage: scripts/sign.sh --identity "Developer ID Application: Name (TEAMID)" [--app <path>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool codesign "Ships with Xcode command line tools"

IDENTITY=""
APP="${REPO_ROOT}/build/DerivedData/Build/Products/Release/UltraSIP.app"
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --identity)
      IDENTITY="${2:?--identity needs a value}"
      shift 2
      ;;
    --app)
      APP="${2:?--app needs a value}"
      shift 2
      ;;
    *) die "unknown argument '${1}'. Usage: sign.sh --identity \"Developer ID Application: ...\" [--app <path>]" ;;
  esac
done

[[ -n "${IDENTITY}" ]] || die "no signing identity given. This script needs the user's Developer ID identity; do not guess one. Usage: sign.sh --identity \"Developer ID Application: Name (TEAMID)\""
[[ -d "${APP}" ]] || die "app bundle not found at ${APP}. Run scripts/build-release.sh first."
[[ "${IDENTITY}" == Developer\ ID\ Application:* ]] || warn "identity does not look like a 'Developer ID Application' certificate; Gatekeeper will reject other types for direct distribution."

ENTITLEMENTS="${REPO_ROOT}/Config/UltraSIP.entitlements"
[[ -f "${ENTITLEMENTS}" ]] || die "entitlements file missing at ${ENTITLEMENTS}"

log "Signing ${APP} with Hardened Runtime..."
codesign --force --options runtime --timestamp \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${IDENTITY}" \
  "${APP}"

log "Verifying signature..."
codesign --verify --strict --verbose=2 "${APP}"
log "Signed. Next: scripts/package.sh, then scripts/notarize.sh (needs notarytool credentials)."
