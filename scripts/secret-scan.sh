#!/usr/bin/env bash
# secret-scan.sh — scan tracked files for credential-shaped content.
# Used by CI and before releases. Patterns are deliberately specific to keep
# false positives low (SPEC.md legitimately discusses "passwords" at length).
# Suppress a confirmed false positive by adding: secretscan:allow on the line.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool git "Install the Xcode command line tools"

cd "${REPO_ROOT}"

PATTERNS=(
  'BEGIN (RSA|EC|DSA|OPENSSH|PGP) PRIVATE KEY'
  'AKIA[0-9A-Z]{16}'
  'ghp_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'sk-[A-Za-z0-9]{32,}'
  'AIza[0-9A-Za-z_-]{35}'
  '(password|passwd|secret|api_key|apikey|auth_token)[[:space:]]*[:=][[:space:]]*"[^"$(){}<>][^"]{7,}"'
)

FOUND=0
for pattern in "${PATTERNS[@]}"; do
  # -I skips binaries; exclude this script (it contains the patterns).
  matches="$(git grep -nIE "${pattern}" -- ':!scripts/secret-scan.sh' 2>/dev/null | grep -v 'secretscan:allow' || true)"
  if [[ -n "${matches}" ]]; then
    printf 'POTENTIAL SECRET (pattern: %s):\n%s\n' "${pattern}" "${matches}" >&2
    FOUND=1
  fi
done

if [[ "${FOUND}" -ne 0 ]]; then
  die "possible secrets found in tracked files (see above). Remove them and rotate any real credential; never commit secrets."
fi
log "No credential-shaped content found in tracked files."
