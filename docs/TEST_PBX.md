# TestPBX

Local, reproducible PBX for integration and media tests.

**Status 2026-07-14: OPERATIONAL.** Runs via `cd TestPBX && docker compose
up -d`; exercised by `scripts/integration-test.sh` tier 2 (registration,
auth failure, echo-media call, 486/404 outcome generators — all passing).
SIPp scenarios still pending. Container specifics: RTP range pinned to the
compose port mapping (rtp.conf), and the UDP transport advertises
`external_media_address=127.0.0.1` because the PBX lives behind Docker's
NAT. Docker's UDP proxy drops oversized datagrams — keep SIP requests
under the RFC 3261 UDP threshold (MacSIP's compact default SDP does).

## Planned layout

```
TestPBX/
├── docker-compose.yml      # single Asterisk service (host networking on
│                           # Linux; mapped UDP/TCP/TLS ports on macOS)
├── asterisk/               # pjsip.conf, extensions.conf, voicemail.conf,
│                           # TLS certs generated at first start (self-signed)
└── sipp/                   # SIPp scenario XMLs + run scripts
```

Asterisk chosen first (best-documented dialplan for feature codes; a
FreeSWITCH variant may be added for the interop matrix later).

## Extensions (per SPEC integration requirements)

| Ext | Purpose |
|---|---|
| 101–103 | Standard test extensions (UDP/TCP/TLS, SRTP optional) |
| 600 | Echo test (media verification: hear yourself = bidirectional RTP) |
| 601 | Tone/milliwatt (unidirectional media + codec check) |
| 700 | Voicemail access |
| \*97 | Voicemail feature code |
| \*\*XXX | Directed pickup (MicroSIP default prefix parity) |
| 800 | Conference room |
| 4xx | Failure generators: 404 / 486 / 480 / 503 / no-answer-timeout |

Auto-answer header tests, forwarding, BLF/presence subscriptions, and
MESSAGE routing are configured in the dialplan; details land with the
config itself.

## Rules

- Test credentials are throwaway and live only in TestPBX/ config — never
  real accounts, never reused anywhere (SPEC: never use customer
  credentials).
- Docker image pulls need user approval (CLAUDE.md).
- CI never runs these (GitHub macOS runners lack Docker); results are
  recorded per-run in docs/INTEROP_TEST_MATRIX.md (created with the first
  real run).
- Media verification standard: see `.claude/skills/interoperability-test/`.
