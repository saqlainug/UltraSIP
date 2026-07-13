#!/usr/bin/env bash
# lint.sh — format + lint. Run before every commit (CLAUDE.md).
#   default: check only (fails on violations)
#   --fix:   apply formatting in place, then re-check
# Uses the swift-format bundled with the Swift 6+ toolchain (no extra deps)
# plus bash -n syntax checks for repository scripts.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root
require_tool swift "Ships with Xcode"

cd "${REPO_ROOT}"
swift format --version >/dev/null 2>&1 || die "swift format subcommand unavailable in this toolchain"

SWIFT_DIRS=(MacSIP Tests)
if [[ "${1:-}" == "--fix" ]]; then
  log "Applying swift format..."
  swift format --in-place --recursive "${SWIFT_DIRS[@]}"
fi

log "Linting Swift sources..."
swift format lint --strict --recursive "${SWIFT_DIRS[@]}" \
  || die "swift format lint failed. Run scripts/lint.sh --fix, review, and re-run."

log "Syntax-checking shell scripts..."
while IFS= read -r -d '' script; do
  bash -n "${script}" || die "bash syntax error in ${script}"
done < <(find "${REPO_ROOT}/scripts" -name '*.sh' -print0)

log "Lint passed."
