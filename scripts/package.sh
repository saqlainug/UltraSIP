#!/usr/bin/env bash
# package.sh — produce distributable ZIP + DMG from a Release universal build.
# Output: dist/MacSIP-<version>.zip, dist/MacSIP-<version>.dmg
# NOTE: artifacts are UNSIGNED (ad-hoc) unless scripts/sign.sh ran first with
# user-held Developer ID credentials. This script never signs or notarizes.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool ditto "Ships with macOS"
require_tool hdiutil "Ships with macOS"

APP="${REPO_ROOT}/build/DerivedData/Build/Products/Release/MacSIP.app"
[[ -d "${APP}" ]] || "${SCRIPT_DIR}/build-release.sh"
[[ -d "${APP}" ]] || die "Release app bundle missing at ${APP}"

VERSION="$(xcconfig_value MACSIP_MARKETING_VERSION)"
[[ -n "${VERSION}" ]] || die "could not read MACSIP_MARKETING_VERSION from Config/Project.xcconfig"

DIST="${REPO_ROOT}/dist"
mkdir -p "${DIST}"

if ! codesign -dv "${APP}" 2>&1 | grep -q "Authority=Developer ID"; then
  warn "App is NOT Developer ID signed — packaging an ad-hoc build (fine for local testing, not for distribution). Run scripts/sign.sh first for release artifacts."
fi

ZIP="${DIST}/MacSIP-${VERSION}.zip"
log "Creating ${ZIP}"
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP}" "${ZIP}"

DMG="${DIST}/MacSIP-${VERSION}.dmg"
log "Creating ${DMG}"
STAGING="$(mktemp -d "${DIST}/dmg-staging.XXXXXX")"
trap 'rm -rf "${STAGING}"' EXIT
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
rm -f "${DMG}"
hdiutil create -quiet -volname "MacSIP ${VERSION}" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}"

log "Packaged:"
ls -lh "${ZIP}" "${DMG}" | awk '{print "  " $NF " (" $5 ")"}'
