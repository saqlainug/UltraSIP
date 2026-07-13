# Parity matrix

Baseline: **MicroSIP 3.22.12** (2026-07-01; docs/RESEARCH_BASELINE.md §1).
Statuses (graduated; never overstated): Not researched · Researched ·
Not started · In progress · Implemented · Unit tested · Integration tested ·
Manually verified · Blocked · Not applicable.

"Researched" means the MicroSIP baseline behavior is documented in
RESEARCH_BASELINE.md; implementation has not begun. A feature may only
graduate with evidence (test run, command output) recorded in the change
that graduates it.

Last full review: **2026-07-13** (Milestone 0 — foundation only; no SIP
functionality exists yet).

| Feature | MicroSIP reference | Status | Source files | Unit | Integration | Manual | PBX dep | Limitations / notes |
|---|---|---|---|---|---|---|---|---|
| **Foundation** ||||||||
| Reproducible PJSIP build (2.17, universal) | bundles PJSIP 2.15.1 | Manually verified 2026-07-13 | scripts/build-pjsip.sh | n/a | n/a | Built both arches locally; lipo verified | — | 9 upstream advisories open (THREAT_MODEL T3) |
| Xcode project, macOS 13+, xcconfig identity | n/a | Manually verified 2026-07-13 | MacSIP.xcodeproj, Config/ | n/a | n/a | Debug build + tests pass | — | — |
| SIP status-code → user text mapping | SPEC §4 table | Unit tested 2026-07-13 | MacSIP/Domain/Calls/SIPStatusMapping.swift | 3 tests pass | n/a | n/a | — | First Domain slice |
| CI (build+test+lint+secret scan) | n/a | Implemented | .github/workflows/ci.yml | n/a | n/a | Not yet run on GitHub | — | Runner label needs Xcode 26 |
| **1. SIP accounts** ||||||||
| Add/edit/delete/enable accounts, full field set | Settings → Accounts | Researched | — | — | — | — | — | Field list SPEC §1 |
| Multiple accounts, one active, switch w/o restart | Yes (one active at a time) | Researched | — | — | — | — | — | — |
| Local account (serverless IP calls) | "Local Account" | Researched | — | — | — | — | — | — |
| Registration lifecycle, status, refresh, failure detail | Yes | Researched | — | — | — | — | — | M1 slice |
| Network / sleep-wake re-registration | Yes | Researched | — | — | — | — | — | NWPathMonitor + NSWorkspace (RB §5) |
| Keychain password storage | ini stores obfuscated pw | Not started | — | — | — | — | — | MacSIP: Keychain-only (stronger than parity) |
| Account import/export | Export/import since 3.22.5 | Researched | — | — | — | — | — | No plaintext secrets by default |
| **2. Transport & SIP security** ||||||||
| UDP / TCP / TLS / UDP+TCP; IPv6 | Yes (UDP+TCP combined mode) | Researched | — | — | — | — | — | — |
| Digest auth; outbound proxy | Yes | Researched | — | — | — | — | — | — |
| TLS system trust + hostname verify; visible insecure override | Yes | Researched | — | — | — | — | — | Apple TLS backend (RB §2) |
| SRTP optional/mandatory | Yes | Researched | — | — | — | — | — | SDES works with current build |
| DTLS-SRTP | Yes (since 3.22.3) | Blocked (decision M2) | — | — | — | — | — | Needs OpenSSL backend (RB §2) — M2 decision |
| **3. Dialer** ||||||||
| Number/URI parsing (tel, E.164, SIP/SIPS URI, IP, params) | Yes | Researched | — | — | — | — | — | — |
| Dial plan language + prefix | Pattern lang: x, [..], <d:s>, ., \| | Researched | — | — | — | — | — | Documented in RB §1 |
| Redial, paste, keyboard entry, suggestions | Yes | Researched | — | — | — | — | — | — |
| Post-connect DTMF (comma pauses) | Yes | Researched | — | — | — | — | — | — |
| **4. Calls** ||||||||
| Outgoing/incoming audio calls, answer/reject/busy/cancel | Yes | Researched | — | — | — | — | — | M1 slice |
| Early media, provisional responses, progress tones | Yes | Researched | — | — | — | — | — | — |
| Hold/resume/swap; auto-hold on switch | Yes (Call Manager) | Researched | — | — | — | — | — | — |
| Mute (mic + remote output) | Yes | Researched | — | — | — | — | — | — |
| Multiple calls, max-calls cap + auto-reject | maxConcurrentCalls (hidden ini) | Researched | — | — | — | — | — | PJSUA_MAX_CALLS default 4 → raise |
| Call waiting | Yes | Researched | — | — | — | — | — | — |
| P-Asserted-Identity / RPID / Diversion display | PAI outgoing since 3.22.5 | Researched | — | — | — | — | — | Untrusted-identity display rules (T13) |
| SIP code → user text (404 ≠ generic) | Yes | Unit tested | Domain/Calls/SIPStatusMapping.swift | ✔ | — | — | — | Wired to real calls at M1 |
| Auto hang-up timer | autoHangUpTime (hidden ini) | Researched | — | — | — | — | — | — |
| **5. DTMF** ||||||||
| RFC 4733, SIP INFO, in-band, auto + preference | auto/RFC2833/in-band/INFO | Researched | — | — | — | — | — | Sensitive: log suppression (T2) |
| **6. Transfer** ||||||||
| Blind transfer (REFER); attended; consultation; failure recovery | Yes (Call Manager) | Researched | — | — | — | — | — | M4 |
| Feature-code fallback (configurable) | Feature Codes settings | Researched | — | — | — | — | — | — |
| **7. Conference** ||||||||
| Local multi-party audio conf (PJSIP bridge), add/remove/end | Yes; AC auto-conference toggle | Researched | — | — | — | — | — | M4 |
| **8. DND / auto-answer / forwarding** ||||||||
| DND toggle + behavior | DND switch | Researched | — | — | — | — | — | — |
| Auto-answer: delay, wildcards, SIP headers, audible warning | AA switch; Call-Info/X-AUTOANSWER headers | Researched | — | — | — | — | — | Header trust policy (T13) |
| Forwarding (immediate/busy/no-answer + delay) | FWD switch | Researched | — | — | — | — | — | PBX-dependent paths documented |
| **9. Audio media** ||||||||
| Device selection (in/out/ring), follow-default, hot-plug recovery | Yes | Researched | — | — | — | — | — | M1 basic; full M3+ |
| Echo cancel, VAD, noise suppression, gain | WebRTC EC + VAD | Researched | — | — | — | — | — | WebRTC AEC compiled in |
| Custom ringtone, sound events, audio test | Yes | Researched | — | — | — | — | — | — |
| Bluetooth/USB/HID headset buttons | Jabra/Plantronics HID | Researched | — | — | — | — | — | Manual-test only items |
| **10. Codecs** ||||||||
| Enable/disable/priority UI; negotiated display | Yes; default-enabled = PCMA+PCMU only | Researched | — | — | — | — | — | Build ships PCMU/PCMA/G.722/GSM/iLBC/Speex |
| Opus | Available in MicroSIP | Not started | — | — | — | — | — | Approved: --with-opus via dependency-review |
| G.729 (bcg729) | Available | Not started | — | — | — | — | — | Approved for later (GPLv3, patents expired) |
| AMR/AMR-WB | Available | Blocked | — | — | — | — | — | Patent terms unconfirmed — do not bundle |
| SILK | Available | Not applicable | — | — | — | — | — | SDK defunct (RB §4) |
| G.723.1 | Available | Not applicable | — | — | — | — | — | No free implementation |
| **11. Call quality stats** ||||||||
| Codec/loss/jitter/RTT/bitrate/SRTP/ICE display + popover | RTCP stats shown | Researched | — | — | — | — | — | M4 |
| **12. Recording** ||||||||
| Per-call + conference recording, indicator, safe filenames | REC button; WAV/MP3 | Researched | — | — | — | — | — | WAV default; MP3 needs license review; AAC native possible |
| **13. Video** ||||||||
| Video calls, camera select, preview, add/remove mid-call | H.264/H.263+ (VP8/VP9 claim unclear) | Researched | — | — | — | — | — | M6: VideoToolbox H.264 + libvpx plan (RB §4) |
| **14. Messaging** ||||||||
| SIP MESSAGE send/receive, conversations, notifications | SIMPLE per RFC 3428; IM tabs | Researched | — | — | — | — | — | M6 |
| **15. Contacts** ||||||||
| Local contacts CRUD, search, favorites, presence column | Yes | Researched | — | — | — | — | — | M5 |
| macOS Contacts read-only integration | n/a (Windows) | Researched | — | — | — | — | — | Permission only when enabled (RB §5) |
| **16. Presence / BLF / pickup** ||||||||
| SUBSCRIBE/NOTIFY/PUBLISH, BLF buttons, directed pickup | Yes; ** prefix default | Researched | — | — | — | — | — | M5; PBX-dependent |
| **17. External directory** ||||||||
| HTTPS JSON/XML directory (+ Cisco/Yealink formats), sequence param, backoff | Yes incl. presence-only feeds | Researched | — | — | — | — | — | XXE-hardened parsing (T6) |
| **18. Call history** ||||||||
| Full outcome/duration/identity records, filters, export | Yes; log DB since 3.22.5 undocumented | Researched | — | — | — | — | — | Import of MicroSIP 3.22.5+ log DB not feasible (format unpublished) |
| **19. Shortcuts** ||||||||
| Programmable shortcuts (BLF/DTMF/transfer/toggle/…) | 8 shortcuts; 3 combined types since 3.22.5 | Researched | — | — | — | — | — | Executable actions: argv-only, off by default (T8) |
| **20. Automation & local control** ||||||||
| URL schemes sip:/sips:/tel:/macsip: | callto:/sip: handling | Researched | — | — | — | — | — | M7 |
| CLI/IPC (dial, answer, hangup, status JSON, …) | CLI switches documented | Researched | — | — | — | — | — | XPC/Unix socket only (T9) |
| Event hooks (call started/ended/…) | cmdCallStart/… hidden ini | Researched | — | — | — | — | — | argv-only, no shell |
| Port knocking | portKnockerHost/Ports hidden ini | Researched | — | — | — | — | — | Parity oddity — decide at M7 whether in scope |
| **21. Import/export** ||||||||
| Versioned export/import (accounts/settings/contacts/shortcuts/history) | Since 3.22.5 | Researched | — | — | — | — | — | Encrypted credential export = opt-in + passphrase (SPEC §21) |
| MicroSIP migration (microsip.ini + Contacts.xml) | UTF-16LE INI + XML schema verified from 3.22.3 src | Researched | — | — | — | — | — | Required feature (CLAUDE.md); round-trip tests |
| **22. Settings** ||||||||
| Full native settings surface (16 sections) | Settings dialog + hidden ini | Researched | — | — | — | — | — | M3+ |
| **23. Diagnostics** ||||||||
| Runtime/env/codec/transport/ICE diagnostics + sanitized export | Log file | Researched | — | — | — | — | — | Redaction tests mandatory (T2) |
