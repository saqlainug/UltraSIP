---
name: release-check
description: Pre-release verification checklist for MacSIP — clean-clone rebuild, universal build, tests, license notices, signing/Hardened Runtime/notarization checks, artifact inspection, secret scan, release notes. Run in full before tagging or distributing any build.
---

# Release check

Signing and notarization need user-held credentials — ALWAYS ask before
`scripts/sign.sh` / `scripts/notarize.sh` (CLAUDE.md). Everything else here
runs without credentials.

## 1. Clean-clone test

```
git clone <repo> /tmp/macsip-releasecheck && cd /tmp/macsip-releasecheck
scripts/bootstrap.sh
scripts/build-pjsip.sh
scripts/build-release.sh
scripts/test.sh
```
Must succeed from scratch with only documented commands. (This is the one
sanctioned write outside the repo: a throwaway clone in a temp dir.)

## 2. Automated checks

- `scripts/lint.sh` clean
- `scripts/test.sh` all pass
- `scripts/integration-test.sh` against TestPBX — pass, or each skip
  documented as environment-dependent with reason
- `scripts/secret-scan.sh` clean
- No new compiler/analyzer warnings vs previous release

## 3. License-notice validation

- LICENSE present (GPLv3) and unmodified
- THIRD_PARTY_NOTICES.md covers every bundled component at its pinned
  version (cross-check DEPENDENCY_LICENSES.md rows against
  ThirdParty/pjsip/dist/BUILD_INFO.txt)
- About/diagnostics screens show correct license + PJSIP version

## 4. Artifact inspection (after sign.sh + package.sh)

```
lipo -archs dist-app/MacSIP.app/Contents/MacOS/MacSIP     # arm64 x86_64
codesign --verify --strict --verbose=2 <app>
codesign -d --entitlements - <app>                        # expected set only
spctl -a -t exec -vv <app>                                # after notarization
xcrun stapler validate <app or dmg>
```
- Entitlements: exactly audio-input, camera (+ any approved additions) —
  nothing stray
- Hardened Runtime flag present (`codesign -d -vv` shows `runtime`)
- DMG/ZIP contents: app only (+ Applications symlink in DMG); no build
  droppings, no .DS_Store surprises

## 5. Release notes + honesty pass

- Notes list user-visible changes, known limitations
  (docs/KNOWN_LIMITATIONS.md updated), and the PJSIP version
- PARITY_MATRIX.md statuses spot-checked against reality — nothing claims
  more verification than was actually run
- README implementation status is accurate for this release

Any failed item blocks the release. Report failures verbatim with commands.
