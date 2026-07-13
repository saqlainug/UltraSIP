# Dependency licenses

Every dependency (and bundled sub-component) with its exact version, source,
checksum, license, and adoption decision. New entries only via the
`dependency-review` skill + `licensing-reviewer` agent (CLAUDE.md).
Project license: **GPLv3** (see LICENSE).

## Adopted

### pjproject (PJSIP/PJSUA2) 2.17

| Field | Value |
|---|---|
| Version / tag | 2.17 (released 2026-04-22) |
| Source | https://github.com/pjsip/pjproject/archive/refs/tags/2.17.tar.gz |
| SHA-256 | `065fe06c06788d97c35f563796d59f00ce52fe9558a52d7b490a042a966facce` (computed from two independent downloads, 2026-07-13) |
| License | GPL-2.0-or-later (dual-licensed with Teluu commercial; we use the GPL branch) — one-way compatible with GPLv3 |
| Patent notes | Codec patent axes tracked per-codec below |
| Build | `scripts/build-pjsip.sh` (pin + flags approval-gated); static libs, universal arm64+x86_64; audio-only baseline; Apple Network.framework TLS backend |
| Security | Nine advisories affect ≤ 2.17 with no patched release as of 2026-07-13 (incl. CVE-2026-57161, HIGH, REGISTER-response path). Tracked in THREAT_MODEL.md; re-check before Milestone 1 leaves the TestPBX. |
| Transitive | Bundled `third_party/` components enumerated below (each with its own license) |
| Decision | **Adopted** 2026-07-13 (Milestone 0) |

Bundled `third_party/` components compiled into our static build
(audio-only configure; video-related components excluded):

| Component | License | Notes |
|---|---|---|
| libsrtp (2.5.0 base) | BSD-3-Clause | SRTP/SDES; possibly pjsip-patched |
| libgsm 1.0.12 | TU-Berlin-2.0 (permissive) | GSM 06.10 codec; patents expired |
| iLBC (RFC 3951 reference) | Internet Society 2004 code terms (pre-IETF-Trust; legally fuzzy but industry-standard practice) | Royalty-free since Google's 2011 BSD relicense of the format's main implementation |
| Speex (+ Speex AEC/DSP) | BSD (Xiph) | Patent-free by design |
| G.722.1 / G.722.1C | Polycom-encumbered | **Disabled** in our build; do not enable without legal review |
| WebRTC AEC | BSD-3-Clause | Echo cancellation |
| resample | LGPL-derived (permissive terms per pjsip distribution) | Verify exact text before first binary release |

### GNU GPLv3 text

LICENSE fetched verbatim from https://www.gnu.org/licenses/gpl-3.0.txt
(2026-07-13; SHA-256 `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`).

## Evaluated — decided, not (yet) adopted

| Candidate | License | Verdict (2026-07-13) |
|---|---|---|
| libopus (Opus) | BSD-3 + patent grants | **Approved for adoption** in the codec milestone via `--with-opus` + fresh dependency-review at the pinned libopus version |
| bcg729 (G.729A/B) | GPLv3 (or commercial) | **Approved for adoption** later via `--with-bcg729`; from-scratch implementation; G.729 patents expired ~2017 |
| libvpx (VP8/VP9) | BSD-3 + WebM patent grant | **Approved for adoption** at Milestone 6 via `--with-vpx` |
| Apple VideoToolbox (H.264) | OS framework (GPLv3 System Library exception) | **Planned** for Milestone 6; no codec code bundled; note: "OS-codec patent coverage" is the industry-standard position, not legally tested |
| opencore-amr / vo-amrwbenc (AMR/AMR-WB) | Apache-2.0 | **Deferred — do not bundle.** Copyright-clean, but no authoritative patent-pool-closure statement located (Wikipedia claims ~2024 expiry). Revisit with confirmed terms only. |
| OpenH264 (self-compiled) | BSD-2 | **Rejected** for bundling: Cisco's AVC fee coverage applies only to the Cisco-distributed binary downloaded at install time; self-compiled builds carry pool exposure until ~2027 |
| x264 | GPL-2.0-or-later | **Rejected**: license-clean but zero patent coverage; heavier than needed |
| SILK | Skype SDK license (defunct) | **Rejected**: SDK officially unobtainable since Skype's 2025-05-05 retirement; mirrors have unclear redistribution rights |
| G.723.1 | n/a | **Rejected**: patents free since 2017 but no maintained free implementation exists |

## Reference-only (not compiled in, not distributed)

| Item | License | Use |
|---|---|---|
| MicroSIP 3.22.3 source | GPL-2.0-or-later (per source headers; site says "GPL v2") | Behavior/format reference (settings.cpp, define.h, Contacts.xml schema). GPL-compatible for study and even code reuse in GPLv3; assets/trademarks excluded (see docs/CLEAN_ROOM_PROCESS.md) |
