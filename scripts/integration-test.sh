#!/usr/bin/env bash
# integration-test.sh — integration tests against the local TestPBX.
#
# Status: NO INTEGRATION TESTS EXIST YET. They arrive with Milestone 1
# (registration + audio-call slice) alongside TestPBX/ provisioning
# (docs/TEST_PBX.md). This script fails honestly rather than reporting a
# fake green; exit code 3 = "not implemented yet", distinct from test
# failure (1) so CI/scripts can tell the difference.
#
# Environment-dependent: requires Docker (TestPBX). GitHub-hosted macOS
# runners cannot run Docker — CI must NOT call this script (CLAUDE.md).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root

if [[ ! -f "${REPO_ROOT}/TestPBX/docker-compose.yml" ]]; then
  log "No TestPBX configuration exists yet (arrives with Milestone 1)."
  log "Nothing was tested. Exiting 3 (not-implemented), NOT success."
  exit 3
fi

require_tool docker "Install Docker Desktop (TestPBX only; see docs/TEST_PBX.md)"
docker compose -f "${REPO_ROOT}/TestPBX/docker-compose.yml" ps --status running | grep -q . \
  || die "TestPBX is not running. Start it: (cd TestPBX && docker compose up -d)"

die "TestPBX exists but no integration test suite is wired up yet (Milestone 1)."
