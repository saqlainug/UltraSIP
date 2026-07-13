---
name: dependency-review
description: Mandatory review procedure before adopting, bundling, or upgrading ANY dependency or codec (library, PJSIP version bump, codec implementation, build tool). No dependency enters the build without completing this checklist and recording it.
---

# Dependency review

CLAUDE.md: every new dependency/codec goes through this skill AND the
licensing-reviewer agent before adoption. PJSIP version changes are
additionally approval-gated (gate 3).

## Required facts (all of them — no adoption with blanks)

1. **Official source** — canonical repo/site URL. No mirrors, no forks,
   no `curl | sh`.
2. **Exact version** — release tag or commit hash.
3. **Checksum** — SHA-256 of the exact artifact, computed from two
   independent downloads; recorded next to the pin in the build script.
4. **License** — SPDX id, verified by reading the actual license file at
   that version (licensing-reviewer agent). GPLv3 compatibility is required.
5. **Patent status** — separate axis from copyright (codecs especially:
   G.729 patents expired 2017; AMR/SILK remain NO without confirmed terms).
6. **Transitive dependencies** — enumerate; each inherits this checklist.
7. **Security advisories** — check the project's advisories/CVEs for the
   pinned version as of today; record what was checked.
8. **Build flags** — exact configure/make flags, recorded in the build
   script; deterministic output.
9. **Architectures** — must build for arm64 AND x86_64 (macOS 13+).
10. **Reproducibility** — a clean clone + documented script must rebuild
    bit-equivalent-enough artifacts; no opaque prebuilt binaries in git.
11. **Update procedure** — how future bumps happen and what re-verification
    they need.

## Recording (all three, same change)

- `DEPENDENCY_LICENSES.md` — full row: name, version, source URL, SHA-256,
  SPDX license, patent notes, decision + date.
- `THIRD_PARTY_NOTICES.md` — attribution/notice text the license requires.
- Build script pin (e.g. `scripts/build-pjsip.sh`) — version + URL +
  checksum + flags in one reviewable block.

## Red flags = stop and ask the user

Checksum mismatch on re-download; license file differs from the project's
advertised license; unmaintained (no release/commit in >2 years) security-
sensitive code; codec with unclear patent posture; any need to disable TLS
verification or signature checks to fetch it.
