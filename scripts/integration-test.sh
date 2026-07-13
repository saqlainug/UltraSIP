#!/usr/bin/env bash
# integration-test.sh — real-SIP integration tests.
#
# Two tiers (both environment-dependent; never faked green):
#   1. LOCAL LOOP (no Docker): drives the app's SIP engine against a real
#      pjsua peer (from our pinned PJSIP build) over localhost UDP —
#      outgoing/incoming calls, bidirectional RTP verification, DTMF
#      delivery, hold/resume, reject-busy.
#   2. TESTPBX (Docker + Asterisk): registration/auth and PBX-dependent
#      scenarios. Skipped with a clear message when Docker is unavailable.
#
# Exit codes: 0 = executed tiers passed · 1 = tests failed ·
#             3 = nothing could run (missing prerequisites)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool xcodebuild "Install Xcode"

PJSUA_BIN="${REPO_ROOT}/ThirdParty/pjsip/src-arm64/pjsip-apps/bin/pjsua-aarch64-apple-darwin"
if [[ "$(uname -m)" == "x86_64" ]]; then
  PJSUA_BIN="${REPO_ROOT}/ThirdParty/pjsip/src-x86_64/pjsip-apps/bin/pjsua-x86_64-apple-darwin"
fi

RAN_ANY=0

# ---- Tier 1: local loop -----------------------------------------------------
if [[ -x "${PJSUA_BIN}" ]]; then
  log "Tier 1: local-loop integration tests (real SIP/RTP via pjsua peer)"
  cd "${REPO_ROOT}"
  set +e
  OUTPUT="$(TEST_RUNNER_MACSIP_INTEGRATION=1 TEST_RUNNER_MACSIP_PJSUA="${PJSUA_BIN}" \
    xcodebuild -project MacSIP.xcodeproj -scheme MacSIP -configuration Debug \
    -only-testing:MacSIPTests/SIPIntegrationTests test 2>&1)"
  STATUS=$?
  set -e
  echo "${OUTPUT}" | grep -E "Test Suite|Test Case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" || true
  if [[ ${STATUS} -ne 0 ]]; then
    echo "${OUTPUT}" | tail -50
    die "local-loop integration tests FAILED (exit ${STATUS})."
  fi
  RAN_ANY=1
  log "Tier 1 passed."
else
  warn "pjsua peer binary missing (${PJSUA_BIN}); run scripts/build-pjsip.sh. Skipping tier 1."
fi

# ---- Tier 2: TestPBX --------------------------------------------------------
if command -v docker >/dev/null 2>&1 \
  && docker compose -f "${REPO_ROOT}/TestPBX/docker-compose.yml" ps --status running 2>/dev/null | grep -q asterisk; then
  log "Tier 2: TestPBX integration tests (registration, auth, PBX-routed media)"
  cd "${REPO_ROOT}"
  set +e
  OUTPUT="$(TEST_RUNNER_MACSIP_PBX=1 \
    xcodebuild -project MacSIP.xcodeproj -scheme MacSIP -configuration Debug \
    -only-testing:MacSIPTests/PBXIntegrationTests \
    -only-testing:MacSIPTests/TransportSecurityTests test 2>&1)"
  STATUS=$?
  set -e
  echo "${OUTPUT}" | grep -E "Test Suite|Test Case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" || true
  if [[ ${STATUS} -ne 0 ]]; then
    echo "${OUTPUT}" | tail -50
    die "TestPBX integration tests FAILED (exit ${STATUS})."
  fi
  RAN_ANY=1
  log "Tier 2 passed."
else
  warn "TestPBX not running (need Docker + 'cd TestPBX && docker compose up -d'). Skipping tier 2."
fi

if [[ "${RAN_ANY}" -eq 0 ]]; then
  log "No integration tier could run. Exiting 3 (not success)."
  exit 3
fi
