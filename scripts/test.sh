#!/usr/bin/env bash
# test.sh — canonical unit-test run (XCTest via xcodebuild).
# Integration tests live in scripts/integration-test.sh (need the TestPBX).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool xcodebuild "Install Xcode"

cd "${REPO_ROOT}"
log "Running unit tests..."
set +e
OUTPUT="$(xcodebuild -project UltraSIP.xcodeproj -scheme UltraSIP -configuration Debug test 2>&1)"
STATUS=$?
set -e
echo "${OUTPUT}" | grep -E "Test Suite|Test Case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" || true
if [[ ${STATUS} -ne 0 ]]; then
  echo "${OUTPUT}" | tail -40
  die "unit tests FAILED (exit ${STATUS}). Full output above; do not report success."
fi
log "Unit tests passed."
