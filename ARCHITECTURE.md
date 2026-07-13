# MacSIP architecture

Native macOS softphone (macOS 13+, universal arm64+x86_64) on PJSIP/PJSUA2.
This document records the layered architecture, the threading model, and the
platform decisions with their evidence (docs/RESEARCH_BASELINE.md).

## Layers

```
┌────────────────────────────────────────────────────────────┐
│ Features/ + Shared/            UI (AppKit shell, SwiftUI   │
│                                content views) — @MainActor │
├────────────────────────────────────────────────────────────┤
│ Domain/                        pure Swift models + logic;  │
│                                no PJSIP, no I/O, no UI     │
├──────────────┬──────────────────────────┬──────────────────┤
│ SIPCore/     │ Persistence/             │ Platform/        │
│ Obj-C++      │ repositories, versioned  │ audio/video devs,│
│ bridge +     │ schema, migrations       │ notifications,   │
│ engine +     │ (no password columns)    │ menu bar, IPC,   │
│ state        │                          │ Contacts, login  │
│ machines     │                          │ item, URL scheme │
├──────────────┴──────────────────────────┴──────────────────┤
│ Security/    Keychain store, certificate policy, redaction,│
│              import validation, secure file writing        │
└────────────────────────────────────────────────────────────┘
```

Protocol boundaries between every pair of layers (UI↔Domain, Domain↔SIP
engine, Domain↔persistence, Domain↔OS services) so that: SwiftUI previews
are deterministic, unit tests run with no SIP server, integration tests use
the real engine, media/notification devices can be mocked, and persistence
is replaceable. **PJSIP types never escape SIPCore** — the bridge emits
immutable Swift event values and accepts value-type commands.

Repository layout follows SPEC (App/, Features/, Domain/, SIPCore/,
Persistence/, Security/, Platform/, Shared/, Resources/ under `MacSIP/`;
`Tests/`, `IntegrationTests/`, `TestPBX/`, `scripts/`, `docs/`, `Config/`
at the root). Identity (product name, bundle id, team, versions) lives
solely in `Config/Project.xcconfig`.

## SIP runtime and threading (the load-bearing design)

Evidence: RESEARCH_BASELINE §3, §6.

- **One SIP runtime** (`SIPCore/Engine/`): owns the PJSUA2 `Endpoint`
  singleton and its full lifecycle — `libCreate → libInit → transport
  create → libStart`, and on shutdown the conservative order
  **calls → accounts → transports → libDestroy** with idempotent teardown.
- **One serialized SIP execution context**: a dedicated, self-managed
  thread wrapped in a serial DispatchQueue abstraction. All PJSIP calls
  hop onto it; nothing else may touch PJSIP. Rationale (verified):
  - Swift actors do not guarantee stable thread identity (SE-0392), and
    custom SerialExecutor support is degraded on a macOS 13 floor
    (DispatchSerialQueue executor conveniences are macOS 14+).
  - GCD pool threads are created/destroyed outside our control; PJSIP's
    `pj_thread_desc` registration dangles when a pooled thread dies
    (documented PJSIP GCD pitfall) — so we own the thread.
  - The engine thread is `pj_thread_register`ed exactly once at startup;
    any auxiliary thread that must touch PJLIB registers-on-first-use
    defensively with a thread-local descriptor.
- **Callbacks**: PJSUA2 worker threads (default 1) deliver callbacks off
  the main thread. Every callback is converted immediately into an
  immutable Swift event value, dispatched to the SIP context for engine
  state mutation, then published to the UI via `@MainActor`. UI state is
  never mutated from a PJSIP callback.
- **Exceptions**: every PJSUA2 call can throw C++ `pj::Error`, and Swift
  cannot catch C++ exceptions — the Obj-C++ bridge catches at the boundary
  and translates to typed Swift errors. No C++ type crosses the bridge.
- **Object lifetime**: `pj::Call` objects are owned by the bridge, stored
  for the call's lifetime, and destroyed on the disconnect callback per
  PJSUA2 docs; Swift holds only value-type call snapshots keyed by stable
  IDs, so stale/duplicate callbacks after disconnect are dropped by ID
  lookup, never dereferenced.
- Limits: `PJSUA_MAX_CALLS` defaults to 4 — raised via config when the
  multi-call milestone lands.

## App shell

**AppKit-primary** for main window chrome, incoming-call floating NSPanel
(cross-Spaces, multi-monitor-safe), menu bar extra, Preferences, and Call
Manager; SwiftUI inside AppKit-hosted content views. Rationale: compact
fixed-density utility window (~360×560 pt), precise focus/keyboard
behavior, and floating-panel semantics SwiftUI does not control well.
CallKit is **not available** to native macOS apps (`CXProvider` is
`API_UNAVAILABLE(macos)`) — the custom panel is the correct mechanism, not
a workaround. Milestone 0 ships a minimal SwiftUI shell (honest
placeholder); the AppKit shell lands with Milestone 3 after approval gate 2
(UI layout spec).

## Platform decisions (with evidence)

| Decision | Choice | Why (RESEARCH_BASELINE ref) |
|---|---|---|
| Sandbox | **No App Sandbox**; Hardened Runtime ON | Developer ID distribution doesn't require sandbox (§5); SIP needs unrestricted UDP/TCP in/out; entitlements limited to audio-input + camera |
| Signing | Ad-hoc for dev/CI (`Config/Project.xcconfig`), Developer ID via `scripts/sign.sh` (user credentials) | macOS 15+ removed the Gatekeeper Control-click bypass — notarized Developer ID is the only viable distribution (§5) |
| TLS backend | Apple Network.framework (`PJ_SSL_SOCK_IMP_APPLE`) | System trust store + no new dependency (§2). configure's "Darwin SSL" autodetect is the deprecated SecureTransport backend and fails on current SDKs |
| DTLS-SRTP | **Out of scope (user decision 2026-07-13)** — SDES-SRTP is the supported media encryption | Requires the OpenSSL backend (confirmed, §2); user waived DTLS-SRTP parity rather than adding OpenSSL |
| SIP stack version | pjproject 2.17 (current stable), not MicroSIP's 2.15.1 | 14+ security fixes; behavior parity ≠ stack-version parity (§2). Nine unpatched advisories tracked in THREAT_MODEL.md |
| Video (M6) | VideoToolbox H.264 + libvpx VP8/VP9 planned | No bundled patent-encumbered codec code (§4) |
| Launch at login | SMAppService.mainApp | The macOS 13+ API; predecessor deprecated (§5) |
| Network/sleep recovery | NWPathMonitor + NSWorkspace sleep/wake notifications → re-registration triggers through the SIP context | §5 |
| Persistence | Repository protocols over SQLite (GRDB-free, custom thin layer) or Core Data — **decided at Milestone 1** with the first schema; versioned migrations, no password columns either way | SPEC allows either with justification |
| Testing | XCTest now; Swift Testing may be adopted for new pure-Swift tests | Both supported in Xcode 26 (§6) |
| Swift mode | Swift 6 language mode; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` for the app target, `nonisolated` for tests; Domain types annotated `nonisolated` where isolation-neutral | SE-0466; Xcode 26 default for new app targets (§6) |

## PJSIP integration mechanics

See docs/PJSIP_INTEGRATION.md: pinned checksum-verified source →
per-arch autoconf builds → `libtool -static` merge → `lipo` universal
`libpjproject.a` + merged headers (arch-differing generated headers get an
`#if defined(__aarch64__)` dispatch shim). The app links the static lib
plus `Network`, `Security`, `CoreAudio`, `AudioToolbox`,
`AVFoundation`, `CoreFoundation` frameworks (exact list finalized when the
bridge lands in Milestone 1).

## Security architecture

THREAT_MODEL.md is authoritative. Structural rules: secrets only in
Keychain (`Security/KeychainStore`), DB stores opaque Keychain references;
`Security/LogRedactor` wraps every log sink (auth data, DTMF, message
bodies) with automated redaction tests; `Security/ImportValidator` bounds
and schema-checks all imports (XML parsing with entities disabled);
`Security/CertificatePolicy` implements system-trust + per-account visible
insecure override (default off). Local control surface (M7) is XPC or a
permission-checked Unix socket — never a network port.
