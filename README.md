# MacSIP

A free, open-source (GPLv3) native macOS softphone built on PJSIP/PJSUA2,
aiming for functional parity with MicroSIP for Windows while keeping its
compact desktop-utility character. macOS 13+, universal (Apple Silicon +
Intel), Swift + Objective-C++, AppKit/SwiftUI.

## ⚠️ Implementation status — read this first

**This project is at Milestone 0 (foundation). It cannot make or receive
calls yet.** Nothing here is a working phone; the app target builds and
shows an honest placeholder window only.

What actually exists today (verified 2026-07-13):

- ✅ Reproducible, checksum-pinned PJSIP 2.17 build → universal static lib
  (`scripts/build-pjsip.sh`)
- ✅ Xcode project (macOS-only, Hardened Runtime, identity via
  `Config/Project.xcconfig`), unit-test target, shared scheme
- ✅ First Domain slice: SIP status-code → user-facing result mapping,
  unit-tested
- ✅ Research baseline with sources (`docs/RESEARCH_BASELINE.md`),
  licensing records, threat model, architecture, parity matrix
- ✅ CI (build + unit tests + lint + secret scan), canonical scripts
- ❌ SIP registration, calling, media, UI beyond a placeholder — all
  tracked honestly in [PARITY_MATRIX.md](PARITY_MATRIX.md)

Milestone plan: docs/SPEC.md ("Milestones"). Next: Milestone 1 — a real
audio-call vertical slice (register → call → bidirectional audio) against
the local test PBX.

## Building

```
scripts/bootstrap.sh      # tool checks + fetch/verify pinned deps
scripts/build-pjsip.sh    # universal static PJSIP (one-time, ~minutes)
scripts/build-debug.sh    # app Debug build
scripts/test.sh           # unit tests
```

Details: [BUILDING.md](BUILDING.md). No Homebrew/cmake/ninja required —
Xcode 26+ and network access to github.com are enough.

## License

GPLv3 (see [LICENSE](LICENSE)). PJSIP is used under its GPL license;
third-party notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
MacSIP is an independent project, not affiliated with MicroSIP; no MicroSIP
assets are used (docs/CLEAN_ROOM_PROCESS.md).

## Contributing / security

[CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) ·
architecture in [ARCHITECTURE.md](ARCHITECTURE.md) · threat model in
[THREAT_MODEL.md](THREAT_MODEL.md).
