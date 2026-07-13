# PJSIP integration

How MacSIP builds, packages, and (from Milestone 1) links PJSIP/PJSUA2.
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
SDES-SRTP works. Milestone 2 decides: adopt OpenSSL via dependency-review,
or document DTLS-SRTP as a limitation.

## Configure flags (baseline)

`--disable-video --disable-ffmpeg --disable-openh264 --disable-vpx
--disable-v4l2 --disable-sdl --disable-opus --disable-opencore-amr`

Compiled-in codecs: PCMU/PCMA, G.722, GSM, iLBC, Speex (+ L16 and G.722.1
present but disabled by default at runtime; G.722.1 stays disabled —
licensing). Opus/bcg729/libvpx are later, approval-gated additions.

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
