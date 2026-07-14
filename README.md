# MacSIP

A free, open-source (GPLv3) native macOS softphone built on PJSIP/PJSUA2,
aiming for functional parity with MicroSIP for Windows while keeping its
compact desktop-utility character. macOS 13+, universal (Apple Silicon +
Intel), Swift + Objective-C++, AppKit/SwiftUI.

## ⚠️ Implementation status — read this first

**Milestone 1 core is working: MacSIP makes and receives real SIP calls
with real RTP audio** — verified by automated integration tests against a
real SIP peer (pjsua) over localhost, with RTP packet counters asserted in
both directions and DTMF delivery confirmed peer-side.

What actually works today (verified 2026-07-13):

- ✅ Outgoing + incoming audio calls (INVITE/200/ACK over UDP), answer,
  reject-as-busy (peer sees 486), hangup — integration-tested
- ✅ Bidirectional RTP media (G.711 via PJSIP conference bridge),
  hold/resume via re-INVITE, RFC 4733 DTMF — integration-tested
- ✅ Keychain-only password storage (round-trip tested); SQLite persistence
  with versioned, tested migrations (no secret columns, enforced by test)
- ✅ Native compact UI (Milestone 3): 360×560 AppKit window with dialpad
  (3×4 keypad), searchable call history, in-call controls, floating
  incoming-call panel (all Spaces, never steals focus), menu-bar extra,
  Settings (launch at login, accounts, audio device selection), DND
- ✅ Reproducible, checksum-pinned PJSIP 2.17 universal build; CI; full
  governance docs (threat model, licensing, research baseline)
- ✅ Registration with digest auth against a real PBX (Asterisk TestPBX),
  including failure detail (401 → "Authentication required"), plus
  PBX-routed calls with relayed RTP verified both ways and correct
  outcome mapping (486 → "Busy", 404 → "Number not found")
- ❌ TLS/SRTP, multiple accounts, transfers, conference, presence,
  messaging, video — later milestones, tracked in
  [PARITY_MATRIX.md](PARITY_MATRIX.md)

Milestone plan: docs/SPEC.md ("Milestones").

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
