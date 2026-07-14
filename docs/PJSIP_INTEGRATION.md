# PJSIP integration

How UltraSIP builds, packages, and (from Milestone 1) links PJSIP/PJSUA2.
Research evidence: docs/RESEARCH_BASELINE.md §2–§3.

## Pin

- pjproject **2.17** (tag `2.17`, 2026-04-22), SHA-256
  `065fe06c06788d97c35f563796d59f00ce52fe9558a52d7b490a042a966facce`.
- Pin + flags live in `scripts/build-pjsip.sh`. Changing them is
  approval-gated (CLAUDE.md gate 3).
- Advisory watch: nine unpatched advisories as of 2026-07-13
  (THREAT_MODEL.md T3) — re-check for 2.17.1 before Milestone 1 leaves the
  TestPBX.

## Build pipeline (`scripts/build-pjsip.sh`)

1. Download the tag archive from github.com/pjsip/pjproject; verify SHA-256
   (two independent downloads were used to establish the pin). Mismatch =
   hard stop.
2. Per-arch trees (`src-arm64`, `src-x86_64`): write our `config_site.h`,
   then `./configure --host=<arch>-apple-darwin` with `-arch` +
   `-mmacosx-version-min=13.0` flags and
   `LIBS="-framework Network -framework Security"`, then
   `make dep && make && make install` into `dist/<arch>/`.
3. `libtool -static` merges each arch's `*.a` set into
   `libpjproject-<arch>.a`; `lipo -create` produces
   `dist/universal/lib/libpjproject.a`.
4. Headers: arm64 tree copied to `dist/universal/include/`; the generated
   per-arch headers that differ (`pj/compat/m_auto.h`, `pj/compat/os_auto.h`)
   are replaced by `#if defined(__aarch64__) / __x86_64__` dispatch shims
   including both variants.
5. `dist/BUILD_INFO.txt` records version, checksum, flags, toolchain, date
   — and gates rebuild-skipping (`--force` to override).

## config_site.h (authoritative copy in the build script)

```c
#define PJ_HAS_SSL_SOCK 1
#define PJ_SSL_SOCK_IMP PJ_SSL_SOCK_IMP_APPLE   /* Network.framework TLS */
#define PJMEDIA_HAS_VIDEO 0                      /* audio-only baseline  */
```

Why not configure's SSL autodetect: on Darwin it probes the legacy
SecureTransport backend ("Darwin SSL", deprecated) with `-Werror`, which
fails on current SDKs — and OpenSSL isn't installed. The modern Apple
backend is selected explicitly instead.

Known consequence: **DTLS-SRTP is unavailable** with the Apple backend
(requires OpenSSL; PJMEDIA_SRTP_HAS_DTLS force-disabled otherwise).
**DECIDED (user approval, 2026-07-13): UltraSIP ships without DTLS-SRTP.**
SDES-SRTP is the supported media encryption; no OpenSSL dependency will be
added for this. Revisiting the decision is approval-gated.

## Configure flags (baseline)

`--disable-video --disable-ffmpeg --disable-openh264 --disable-vpx
--disable-v4l2 --disable-sdl --disable-opus --disable-opencore-amr`

Compiled-in codecs: PCMU/PCMA, G.722, GSM, iLBC, Speex, and **G.729 via
bcg729 1.1.1** (adopted 2026-07-14 — GSM-termination switches are often
G.729-only; bcg729 is compiled per-arch with plain clang, no cmake, and
linked via `--with-bcg729`). L16 and G.722.1 remain disabled at runtime
(G.722.1 for licensing). Opus/libvpx are later additions.

Runtime-enabled priority order: PCMU (200) > PCMA (190) > G722 (180) >
G729 (170); all other compiled codecs are priority 0.

VAD/silence suppression is OFF endpoint-wide (`medConfig.noVad = true`) —
MicroSIP's default. PJSUA's default (VAD on) makes G.729 Annex B DTX
collapse a silent stream to a single 2-byte SID frame, which strict
gateways treat as dead RTP; continuous media is the parity behavior until
a codec-settings UI exposes the toggle.

Offers are AUDIO-ONLY: PJSIP 2.17 defaults txt_cnt (RFC 4103 real-time
text) to 1, adding an m=text line MicroSIP never sends; at least one
GSM-termination SBC answers such offers unusably. All CallOpParam sites
go through USPAudioOnlyCallParam().

Interop guard `usp-sdp-guard` (module, priority TRANSPORT_LAYER+1):
strips an SDP body containing zero m= lines from provisional INVITE
responses. Observed live: a reliable 180 (Require: 100rel) carrying
`c=IN IP4 0.0.0.0` and no m-lines — RFC 3262 makes that the answer and
the call dies with PJMEDIA_SDPNEG_ENOMEDIA before the 200 OK's real
answer. Early media (any m-line present) is never touched. Covered by
BrokenGatewayTests against a scripted raw-UDP UAS.

Interop debugging: DEBUG builds run at PJSIP log level 5 by default —
full SIP traces incl. SDP, console only (`ULTRASIP_NO_SIP_TRACE=1` in the
environment quiets a run). Not compiled into release builds (traces carry
Authorization headers).

## Linking (Milestone 1)

The app links `dist/universal/lib/libpjproject.a` with
`HEADER_SEARCH_PATHS = ThirdParty/pjsip/dist/universal/include` and (at
minimum) frameworks: `Network`, `Security`, `CoreAudio`, `AudioToolbox`,
`AVFoundation`, `CoreFoundation`. Exact list is finalized when the bridge
lands; link errors name the missing framework symbol prefix (`_nw_*` →
Network, `_sec_*` → Security).

## PJSUA2 usage rules (bridge contract — enforced in review)

- Endpoint singleton lifecycle: `libCreate → libInit → transports →
  libStart`; shutdown `calls → accounts → transports → libDestroy` (then
  delete Endpoint).
- One dedicated registered engine thread; callbacks arrive on PJSUA2
  worker threads → converted to immutable events, never touched further on
  the callback thread.
- Every PJSUA2 call wrapped in try/catch(pj::Error&) at the bridge
  boundary → NSError/typed Swift error. C++ never crosses into Swift.
- `pj::Call` objects owned by the bridge; deleted on disconnect callback;
  Swift sees value snapshots keyed by stable IDs only.
- `PJSUA_MAX_CALLS` default is 4 — raise in EpConfig when multi-call lands.
