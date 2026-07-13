#!/usr/bin/env bash
# clean-generated.sh — remove generated artifacts. Touches ONLY documented
# directories inside the repository:
#   ThirdParty/pjsip/   (PJSIP build trees + dist; regenerable)
#   build/              (xcodebuild output)
#   dist/               (packaging output)
# The verified source tarball in ThirdParty/cache/ is kept unless --all.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root

for dir in "ThirdParty/pjsip" "build" "dist"; do
  target="${REPO_ROOT}/${dir}"
  if [[ -d "${target}" ]]; then
    log "Removing ${dir}/"
    rm -rf "${target}"
  fi
done

if [[ "${1:-}" == "--all" ]]; then
  log "Removing ThirdParty/cache/ (pinned tarball will re-download on next build)"
  rm -rf "${REPO_ROOT}/ThirdParty/cache"
fi

log "Clean complete. DerivedData outside the repo is untouched (owned by Xcode)."
