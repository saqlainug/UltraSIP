#!/usr/bin/env bash
# Shared helpers for UltraSIP scripts. Source this file; do not execute it.
# Callers must set REPO_ROOT before sourcing (see any script header).

set -euo pipefail

log() { printf '[%s] %s\n' "$(basename "${0}")" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$(basename "${0}")" "$*" >&2; }
die() {
  printf '[%s] ERROR: %s\n' "$(basename "${0}")" "$*" >&2
  exit 1
}

# require_tool <name> <hint printed when missing>
require_tool() {
  command -v "${1}" >/dev/null 2>&1 || die "required tool '${1}' not found. ${2:-}"
}

# Guard: refuse to run from outside the repository.
assert_repo_root() {
  [[ -f "${REPO_ROOT}/CLAUDE.md" && -d "${REPO_ROOT}/UltraSIP.xcodeproj" ]] \
    || die "REPO_ROOT '${REPO_ROOT}' does not look like the UltraSIP repository"
}

# xcconfig_value <KEY> — read a value from Config/Project.xcconfig.
xcconfig_value() {
  sed -n "s/^${1} *= *//p" "${REPO_ROOT}/Config/Project.xcconfig" | head -1
}
