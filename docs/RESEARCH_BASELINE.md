# Research baseline — Milestone 0

Retrieved **2026-07-13** by a fan-out web-research pass with adversarial
verification against primary sources. Every finding lists: source, retrieval
date, version it applies to, the decision it affects, and uncertainty.
Verification status: **CONFIRMED** = an independent adversarial verifier
re-checked the primary source; **PLAUSIBLE** = researched from primary
sources but the verifier pass did not complete (session limits) — treat as
reliable but re-verify before relying on the exact wording.

---

## 1. MicroSIP baseline (parity target)

| Fact | Value | Source | Verified |
|---|---|---|---|
| Current stable version | **3.22.12** (2026-07-01) | microsip.org/downloads | CONFIRMED |
| License | Site says "GNU GPL v2"; source headers in official 3.22.3 source archive say GPL **v2 or later** (SPDX `GPL-2.0-or-later`). No standalone COPYING file in the archive. | microsip.org/download/MicroSIP-3.22.3-src.7z | CONFIRMED |
| SIP stack | PJSIP; bundled version documented as **2.15.1** since MicroSIP 3.22.3; no later changelog bump through 3.22.12 | microsip.org/downloads (changelog) | CONFIRMED (presumptive for 3.22.5+, source unpublished) |
| Source availability | Official source archives lag binaries: newest is **3.22.3-src**; no official git repo. 3.22.5+ internals (call-log DB, export format) cannot be verified from official channels. | microsip.org/source | CONFIRMED |
| Settings storage | `microsip.ini` — **UTF-16LE with BOM**, INI format. Installed mode: `%APPDATA%\MicroSIP\microsip.ini`; portable mode: next to the exe. Verified from 3.22.3 `settings.cpp`. | official source 3.22.3 | CONFIRMED |
| Contacts storage | `Contacts.xml` in the same directory, attribute-based schema | official source 3.22.3 | CONFIRMED |
| Call log | Moved to a separate **undocumented database file** in 3.22.5 (format unverifiable — source unpublished) | changelog | CONFIRMED (format unknown) |
| Codecs available | Opus, G.711 A/µ, G.722, "G.721.1" (almost certainly a site typo for G.722.1), G.723, G.729, GSM, AMR, AMR-WB, iLBC, Speex, SILK, L16. **Default-enabled on fresh install: PCMA + PCMU only** (3.22.3 `define.h`). | microsip.org + source | CONFIRMED |
| Video codecs | Help documents H.264 (default) + H.263+; homepage additionally claims VP8/VP9 (support level unclear) | microsip.org/help | CONFIRMED (VP8/VP9 ambiguity noted) |
| Standards claimed | DTMF: in-band, RFC 2833, SIP INFO. Messaging: RFC 3428 (SIMPLE). Presence: RFC 3903 PUBLISH + RFC 6665 SUBSCRIBE/NOTIFY. TLS; SRTP; DTLS-SRTP (added 3.22.3). BLF + Asterisk pickup since 3.19.31. | microsip.org | CONFIRMED |

Feature-set details captured for the parity matrix (from microsip.org/help,
2026-07-13): two UI modes (Single Call / Call Manager with per-session tabs,
IM tabs, auto-hold on switch, Last Call); toggles DND / FWD / AC
(auto-conference) / AA (auto-answer) / CONF / REC; presence + BLF + directed
pickup (default prefix `**`, configurable feature codes); multiple accounts
(one active at a time) + Local Account for serverless IP calls; per-account
dial plan pattern language (`x`, `[ranges]`, `<dialed:substituted>`, `.`
repetition, `|` alternatives; non-matching numbers blocked) + dialing prefix;
hide caller-ID (two modes); voicemail number; media encryption modes
Disabled / Optional SRTP / Mandatory SRTP / DTLS-SRTP+SRTP / DTLS-SRTP;
transports UDP, TCP, TLS, UDP+TCP; public address, IP rewrite, STUN, ICE,
session timers; auto-answer via delay + caller wildcards + SIP headers
(`Call-Info: Auto Answer`, `Call-Info: answer-after=0`, `X-AUTOANSWER:
TRUE`); deny-incoming filters; HTTP(S) directory in JSON/XML/Cisco/Yealink
formats (refresh/silent/`sequence` params, presence-only feeds); 8
programmable shortcuts (`_GLOBAL_SHORTCUTS_QTY 8`; Toggle/BLF/DTMF + 3
combined types since 3.22.5); DTMF auto/RFC2833/in-band/INFO + post-connect
sequences after comma; custom SIP headers/URI params in full-URI dialing;
media-button + Jabra/Plantronics HID headset support; sound events; log
file; CLI control (`call`, `/hangupall`, `/hangupincoming`,
`/hangupcalling`, `/answer`, `/transfer:XXX`, `/dtmf:`, `/minimized`,
`/reset`, `/exit`); hotkeys F2/F4; hidden ini-only settings
(`cmdCallStart/End/IncomingCall/Answer`, `autoHangUpTime`,
`maxConcurrentCalls`, `noResize`, `userAgent`, `multiMonitor`,
`portKnockerHost/Ports`); export/import of accounts/settings/shortcuts/call
log since 3.22.5; P-Asserted-Identity on outgoing since 3.22.5.

**Decisions affected:** parity matrix baseline = MicroSIP **3.22.12**;
migration importer must parse UTF-16LE INI + Contacts.xml (formats verified
only against 3.22.3 source); call-log import limited to MacSIP's own format
+ documented MicroSIP formats (3.22.5+ DB is undocumented); studying
MicroSIP GPL-2.0-or-later source inside this GPLv3 project is
license-compatible (one-way).

---

## 2. PJSIP / pjproject (the dependency pin)

| Fact | Value | Source | Verified |
|---|---|---|---|
| Current stable | **2.17**, tag `2.17`, published 2026-04-22. Previous: 2.16 (2025-11-26), 2.15.1 (2024-12-16). | api.github.com/repos/pjsip/pjproject/releases | CONFIRMED |
| Archive + checksum | `https://github.com/pjsip/pjproject/archive/refs/tags/2.17.tar.gz`, SHA-256 `065fe06c06788d97c35f563796d59f00ce52fe9558a52d7b490a042a966facce` (computed locally from two independent downloads, 2026-07-13) | local verification | CONFIRMED |
| License | Dual: **GPL v2 or later** + commercial (Teluu). GPLv2+ combines one-way into GPLv3. Caveat: `third_party/` components carry their own licenses (see THIRD_PARTY_NOTICES.md). | pjsip.org/licensing.htm | CONFIRMED |
| macOS build | Builds on modern macOS/clang via autoconf; per-arch builds + `lipo` is the documented universal pattern; `libtool -static` merge + optional XCFramework is the documented Apple packaging. Locally proven: 2.17 built for arm64 + x86_64 with Xcode 26.6 (see `ThirdParty/pjsip/dist/BUILD_INFO.txt`). | docs.pjsip.org build instructions + local build | CONFIRMED (local) |
| TLS backends | Six, via `PJ_SSL_SOCK_IMP`: OPENSSL, GNUTLS, DARWIN (legacy SecureTransport, deprecated by Apple), **APPLE (Network.framework, macOS 10.15+)**, SCHANNEL, MBEDTLS. configure's "Darwin SSL" autodetect is the legacy backend and fails on current SDKs; we force `PJ_SSL_SOCK_IMP_APPLE` in `config_site.h` (+ link `Network`/`Security`). | docs.pjsip.org security/ssl | PLAUSIBLE (verifier did not complete; backend choice proven by local build) |
| **DTLS-SRTP constraint** | **DTLS-SRTP requires the OpenSSL backend.** `PJMEDIA_SRTP_HAS_DTLS` is force-disabled for every other backend (build emits a `#pragma message`; at runtime calls silently offer SDES-only). | docs.pjsip.org security/srtp + security/ssl | CONFIRMED |
| SRTP | SDES-SRTP enabled by default; bundled libsrtp **2.5.0** base (possibly locally patched); keying priority SDES first. | pjproject 2.17 third_party/srtp/CHANGES | CONFIRMED |
| Built-in codecs (no external libs) | PCMU/PCMA, G.722, GSM FR, iLBC, Speex (all enabled by default); L16 (disabled by default); **G.722.1/G.722.1C bundled but patent/licensing-encumbered** (Polycom/Siren — keep disabled pending legal check). Opus requires external libopus (`--with-opus`). | docs.pjsip.org pjmedia-codec | CONFIRMED |
| Video on macOS | AVFoundation capture; Metal renderer (since 2.15); H.264 via Apple **VideoToolbox** (since 2.7, `PJMEDIA_HAS_VID_TOOLBOX_CODEC`); VP8/VP9 via `--with-vpx`. | docs.pjsip.org | CONFIRMED (default-enablement of VideoToolbox in plain configure unverified) |
| **Security advisories** | **Nine GitHub advisories affect ≤ 2.17 with NO patched release as of 2026-07-13** (fixes are master-only commits). Highest relevance: CVE-2026-57161 / GHSA-xc62-j9h2-mp84 (HIGH) — stack overflow parsing Service-Route headers in a REGISTER **response**, i.e. the default PJSUA2 registration path MacSIP will use in Milestone 1. | github.com/pjsip/pjproject/security/advisories | CONFIRMED |

**Decisions affected:**
- **Pin = 2.17** (current stable; 14+ security fixes over 2.16; MicroSIP
  itself lags on 2.15.1 — parity of behavior does not require parity of
  stack version).
- **Advisory posture:** before Milestone 1 connects to anything untrusted,
  re-check for a 2.17.1 release; if none, evaluate cherry-picking the nine
  fix commits into the pinned build (a pin change → approval gate 3).
  Tracked in THREAT_MODEL.md. Local TestPBX-only testing keeps exposure nil
  meanwhile.
- **TLS:** Apple Network.framework backend for M0/M1 (no new dependency).
  **Milestone 2 decision:** MicroSIP parity lists DTLS-SRTP → either adopt
  OpenSSL via dependency-review (enables DTLS-SRTP) or document SDES-SRTP
  as the supported keying with DTLS-SRTP as a known limitation.

---

## 3. PJSUA2 integration pattern

| Fact | Value | Source | Verified |
|---|---|---|---|
| Endpoint lifecycle | Singleton; `libCreate()` → `libInit(EpConfig)` → create transports → `libStart()`; shutdown via explicit `libDestroy()` then delete. Safe to call libDestroy more than once. | docs.pjsip.org pjsua2/using/endpoint | CONFIRMED |
| Callback threading | PJSUA2 runs its own worker thread(s) (default `threadCnt` = 1); callbacks arrive on non-main threads; PJSUA2 itself is thread-safe. `mainThreadOnly` exists but is designed around a UI-thread polling model we do not use. | docs.pjsip.org general_concept | CONFIRMED |
| Thread registration | Any thread not created by `pj_thread_create()` MUST call `pj_thread_register()` before any PJLIB call, from that thread; the `pj_thread_desc` must outlive the thread's PJLIB use; unregistered calls assert. | docs.pjsip.org PJ_THREAD group | PLAUSIBLE (verifier did not complete) |
| GCD pitfall | Official docs (iOS page; Darwin-identical mechanics): GCD pool threads die outside app control → registered descriptors dangle; `libRegisterThread` leaks a descriptor per call until libDestroy. Documented workaround: **create and manage your own thread**. | docs.pjsip.org get-started/ios/issues | PLAUSIBLE (verifier did not complete) |
| Universal build | Per-arch `./configure --host=<arch>-apple-darwin` with `-arch` CFLAGS/LDFLAGS, `make dep && make`, then `libtool -static` merge + `lipo`. (Docs show `arm-apple-darwin`; `arm64-apple-darwin` also accepted — we use the latter.) | docs.pjsip.org build instructions | PLAUSIBLE (proven locally regardless) |
| Worker/limits | Default worker threads 1; `PJSUA_MAX_CALLS` **default 4** (docs claiming 32 are stale) — must raise via config for multi-call/conference milestones. | pjsua.h at 2.17 | CONFIRMED |
| Exceptions | Every PJSUA2 call may throw C++ `pj::Error`. Swift cannot catch C++ exceptions (fatal). → Obj-C++ bridge must catch at the boundary and translate to NSError/typed Swift errors. | docs.pjsip.org + swift.org/documentation/cxx-interop/status | CONFIRMED |
| Call object lifetime | Store the `pj::Call` subclass instance for the call's lifetime; after the disconnect callback returns the call object is invalid; docs recommend deleting it inside the disconnect callback. Swift layer must never hold references past disconnect notification. | docs.pjsip.org pjsua2/using/call | CONFIRMED |
| Account/shutdown | `Account` destructor calls `shutdown()`; derived classes should call `shutdown()` early in their destructor. Safe order (inferred best practice, not hard requirement): delete calls → accounts → transports → `libDestroy()`. | account.hpp at 2.17 | PLAUSIBLE (verifier did not complete) |

**Decisions affected:** SIPCore uses ONE dedicated, self-managed thread
(serial DispatchQueue targeting a thread we own, registered once) — not
actors, not raw GCD pool queues (see §6 and ARCHITECTURE.md); bridge catches
all C++ exceptions at the boundary; teardown ordering codified in CLAUDE.md
threading rule 4.

---

## 4. Codec licensing (GPLv3 binary distribution)

| Codec | Implementation | License | Patent status (2026) | Verdict | Verified |
|---|---|---|---|---|---|
| Opus | libopus | BSD-3 + Xiph/Broadcom/Microsoft patent grants (defensive termination) | Grants royalty-free; no litigation since 2012 | **Adopt** (Milestone with `--with-opus`, via dependency-review) | CONFIRMED |
| G.711 (PCMU/PCMA) | built-in | — | Expired long ago | **Ship** (in current build) | CONFIRMED |
| G.722 | built-in | — | Expired | **Ship** (in current build) | CONFIRMED |
| GSM 06.10 | bundled libgsm 1.0.12 | TU-Berlin-2.0 (permissive) | Expired | **Ship** (in current build) | CONFIRMED |
| iLBC | bundled (RFC 3951 reference, Internet Society 2004 headers, pre-Trust terms — legally fuzzy but industry-shipped) or WebRTC BSD copy | see left | Royalty-free since Google's 2011 BSD release | **Ship bundled copy**; note header caveat in notices | CONFIRMED |
| Speex | bundled (Xiph) | BSD | Patent-free by design | **Ship** (parity only; obsolete vs Opus) | CONFIRMED |
| G.722.1 (Siren7) | bundled but **disabled** | Polycom-encumbered | License required | **Keep disabled** pending legal check | CONFIRMED |
| G.723.1 | none maintained/free | — | Royalty-free since 2017-01-01 | **Skip** (no viable implementation) | CONFIRMED |
| G.729 | **bcg729** (Belledonne; from-scratch, not ITU-derived) | **GPLv3** (or commercial) — compatible | Patents expired by ~2017 | **Adopt later** via `--with-bcg729` + dependency-review | CONFIRMED |
| AMR / AMR-WB | opencore-amr + vo-amrwbenc | Apache-2.0 (compatible) | Pool expiry ~2024 per Wikipedia; **no authoritative pool-closure statement found** | **Defer — do not bundle** until terms confirmed (CLAUDE.md rule) | CONFIRMED |
| SILK | none | Skype SDK license defunct; Skype retired 2025-05-05; SDK unobtainable officially | n/a | **Reject** | CONFIRMED |
| H.264 | OpenH264 (BSD source; Cisco patent-fee coverage ONLY for the Cisco-distributed binary downloaded at install time); x264 (GPL, no patent coverage); **Apple VideoToolbox** (OS-provided, System Library exception, no bundled codec code) | see left | AVC pool active until ~2027 for self-built encoders | **Plan: VideoToolbox** for M6 (industry-standard position that OS-codec use is covered; note this is untested legally) | CONFIRMED |
| VP8/VP9 | libvpx | BSD-3 + WebM patent grant (FSF: GPLv3-compatible) | Royalty-free | **Adopt at M6** via `--with-vpx` + dependency-review | CONFIRMED |

---

## 5. Apple platform requirements (Developer ID, macOS 13+)

| Fact | Value | Source | Verified |
|---|---|---|---|
| Mic/camera permission | `NSMicrophoneUsageDescription` + `NSCameraUsageDescription` required (exception without them); `AVCaptureDevice.authorizationStatus/requestAccess`; system prompts on first `AVCaptureDeviceInput` creation; until granted, black frames / silent audio. | developer.apple.com | CONFIRMED |
| Hardened Runtime entitlements | Non-sandboxed Developer ID app needs `com.apple.security.device.audio-input` + `com.apple.security.device.camera` for mic/camera. (Both present in `Config/MacSIP.entitlements`.) | developer.apple.com entitlements | CONFIRMED |
| Contacts | `CNContactStore` + `NSContactsUsageDescription`; limited-access model is iOS-18-only, not native macOS as of today. Add the addressbook entitlement only when the feature ships. | developer.apple.com | CONFIRMED |
| Notifications | `UNUserNotificationCenter.requestAuthorization`; **works only from a bundled app context** — unit-test hosts/CLI crash (relevant to how we test notification code). | developer.apple.com + DTS | CONFIRMED |
| Launch at login | **SMAppService.mainApp** (macOS 13+) `register()`/`unregister()`; `SMLoginItemSetEnabled` deprecated at 13.0. Denial returns `kSMErrorLaunchDeniedByUser`. | developer.apple.com/documentation/servicemanagement/smappservice | CONFIRMED |
| Notarization | notarytool mandatory since 2023-11-01 (altool retired); Hardened Runtime required; staple recommended. macOS 15+: **no Control-click Gatekeeper bypass** — users must approve in System Settings, so unsigned/un-notarized distribution is effectively non-viable. | developer.apple.com | CONFIRMED |
| Sandbox | NOT required for Developer ID (store-only requirement). Decision: no sandbox (documented in ARCHITECTURE.md); if ever sandboxed, would need network client+server + device entitlements. | developer.apple.com App Sandbox | CONFIRMED |
| CallKit | `CXProvider` etc. are `API_UNAVAILABLE(macos)` in the macOS 26.5 SDK — **no CallKit for native macOS apps**; custom incoming-call UI (NSPanel) is the correct plan. | SDK headers + docs | CONFIRMED |
| Network/sleep | `NWPathMonitor` (10.14+) for path changes → re-registration triggers; `NSWorkspace.willSleepNotification` (30 s grace) / `didWakeNotification`. | developer.apple.com | CONFIRMED |

---

## 6. Swift / Xcode toolchain

| Fact | Value | Source | Verified |
|---|---|---|---|
| Deployment target | Xcode 26.6 (Swift 6.3.3, macOS 26.5 SDK) supports macOS deployment targets **11–26.5** → 13.0 fully supported; empirically compiled for both arches. | developer.apple.com/support/xcode | CONFIRMED |
| Default actor isolation | SE-0466 (Swift 6.2): per-module default isolation; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is the Xcode-26 default for NEW app targets and Apple's recommendation for UI-facing modules. We use MainActor default for the app target, `nonisolated` for the test target (XCTest init override conflict otherwise — hit and fixed in this repo). | SE-0466 + WWDC25 session 268 | CONFIRMED |
| C++ interop | Swift cannot catch C++ exceptions (fatal at the boundary) and cannot subclass C++ classes / override C++ virtuals — PJSUA2 is consumed by subclassing + throws everywhere → **Obj-C++ bridge is mandatory**, validating the SPEC architecture. | swift.org/documentation/cxx-interop/status | CONFIRMED |
| Actor thread identity | SE-0392: default actor executors do NOT guarantee stable thread identity (only MainActor is thread-bound). Custom SerialExecutors are viable but degraded on a macOS 13 floor (`DispatchSerialQueue` executor conveniences are macOS 14+; isolation-checking runtime gaps on 13). → **Dedicated self-managed registered thread** for the SIP context. | SE-0392 + SerialExecutor docs | CONFIRMED |
| Testing | XCTest and Swift Testing coexist in Xcode 26; Swift Testing is Apple's recommendation for new unit tests; XCTest not deprecated. MacSIP currently uses XCTest; adopting Swift Testing for new pure-Swift tests is open. | WWDC26 session 267 | CONFIRMED |
| swift-format | Bundled since Swift 6.0 as `swift format`; local version 6.3.0 verified. `scripts/lint.sh` relies on it (no third-party lint dependency). | swiftlang/swift-format + local | CONFIRMED |
| SPM | Local packages with `platforms: [.macOS(.v13)]` build/test fine on the 26.x toolchain (execution proven on host OS only). | PackageDescription docs + local | CONFIRMED |
| Swift 6.3 changes | No runtime scheduling/executor behavior changes vs 6.2; compile-time improvements only (region-based isolation maturity, `@c`, module selectors). | swift.org/blog/swift-6.3-released | CONFIRMED |

---

## Re-verification queue

The following PLAUSIBLE items should be re-verified opportunistically (their
verifier agents were cut off; the facts came from primary sources and two are
already proven by the local build):

1. TLS backend enumeration exact macro values (proven functionally by local build).
2. `pj_thread_register` exact doc wording (design already assumes the strict reading).
3. GCD/`pj_thread_desc` dangling-descriptor mechanics (design avoids GCD pool threads entirely).
4. Universal build recipe doc wording (proven locally).
5. Xcode packaging (XCFramework) doc wording (we use fat .a + header paths).
6. Account-before-libDestroy strict ordering (we follow the conservative order regardless).
