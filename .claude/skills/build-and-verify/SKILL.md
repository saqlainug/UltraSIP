---
name: build-and-verify
description: Canonical MacSIP build + verification sequence. Use before claiming any change works, before every commit of implementation code, and at session end. Defines the exact order of clean build, debug/release builds, unit tests, integration tests, static analysis, sanitizers, and honest result reporting.
---

# Build and verify

Use the canonical scripts only (CLAUDE.md: do not invent variants). Run from
the repo root. Report EXACT command output — never summarize a failure away.

## Standard loop (every implementation change)

```
scripts/build-debug.sh
scripts/test.sh
scripts/lint.sh
```

All three must pass before a commit. If PJSIP sources changed or ThirdParty/
is missing: run `scripts/build-pjsip.sh` first (checksum-verified; slow).

## Full verification (before ending a session / marking a slice done)

1. `scripts/lint.sh` — zero violations.
2. `scripts/build-debug.sh` — zero warnings introduced (compare, don't guess).
3. `scripts/test.sh` — all unit tests pass.
4. `scripts/integration-test.sh` — only with TestPBX up (`cd TestPBX && docker
   compose up -d`). If the environment lacks Docker, record "environment-
   dependent skip" with the exact reason; NEVER report it as passed.
5. `scripts/build-release.sh` — universal build succeeds; lipo check is
   built into the script.
6. `scripts/secret-scan.sh` — clean.

## Clean-room rebuild (suspected stale state, release prep)

```
scripts/clean-generated.sh
scripts/bootstrap.sh
scripts/build-pjsip.sh
scripts/build-release.sh
scripts/test.sh
```

## Static analysis and sanitizers

- Analyzer: `xcodebuild -project MacSIP.xcodeproj -scheme MacSIP analyze`
  (treat new analyzer warnings as failures).
- Thread Sanitizer (threading bugs in SIPCore are the #1 crash source):
  `xcodebuild -project MacSIP.xcodeproj -scheme MacSIP -enableThreadSanitizer YES test`
- Address Sanitizer (Obj-C++ bridge memory safety):
  `xcodebuild -project MacSIP.xcodeproj -scheme MacSIP -enableAddressSanitizer YES test`
- Run TSan/ASan at minimum before each milestone completion and after any
  SIPCore/bridge change.

## Reporting rules

- Quote the command and its tail output for both success AND failure.
- On failure classify the cause: code / environment / dependency / license /
  credential / platform (CLAUDE.md failure handling).
- Media-touching features are not "verified" by green tests alone —
  see the interoperability-test skill for media verification.
