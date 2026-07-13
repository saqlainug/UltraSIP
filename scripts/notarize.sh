#!/usr/bin/env bash
# notarize.sh — submit a signed artifact to Apple notarization and staple.
# REQUIRES USER-HELD CREDENTIALS (a notarytool keychain profile created by
# the user: xcrun notarytool store-credentials). Never run without explicit
# user approval (CLAUDE.md). This script never handles raw passwords.
#
# Usage: scripts/notarize.sh --profile <keychain-profile> --file <zip-or-dmg> [--staple <app-or-dmg>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool xcrun "Ships with Xcode command line tools"

PROFILE=""
FILE=""
STAPLE_TARGET=""
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --profile)
      PROFILE="${2:?--profile needs a value}"
      shift 2
      ;;
    --file)
      FILE="${2:?--file needs a value}"
      shift 2
      ;;
    --staple)
      STAPLE_TARGET="${2:?--staple needs a value}"
      shift 2
      ;;
    *) die "unknown argument '${1}'. Usage: notarize.sh --profile <keychain-profile> --file <zip-or-dmg> [--staple <path>]" ;;
  esac
done

[[ -n "${PROFILE}" ]] || die "no notarytool keychain profile given (user-held credential; create with: xcrun notarytool store-credentials)"
[[ -f "${FILE}" ]] || die "artifact not found: ${FILE}"

log "Submitting ${FILE} for notarization (waits for result)..."
xcrun notarytool submit "${FILE}" --keychain-profile "${PROFILE}" --wait \
  || die "notarization failed. Inspect with: xcrun notarytool log <submission-id> --keychain-profile ${PROFILE}"

if [[ -n "${STAPLE_TARGET}" ]]; then
  log "Stapling ticket to ${STAPLE_TARGET}..."
  xcrun stapler staple "${STAPLE_TARGET}"
  xcrun stapler validate "${STAPLE_TARGET}"
fi
log "Notarization complete."
