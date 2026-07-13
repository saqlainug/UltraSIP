# TestPBX

Local, reproducible PBX for integration and media tests.

**Status 2026-07-13: compose file + Asterisk configs are WRITTEN
(TestPBX/) but have NEVER RUN — Docker is not installed on the primary dev
machine.** First run: install Docker Desktop/OrbStack, approve the
`andrius/asterisk` image download (CLAUDE.md), `cd TestPBX && docker
compose up -d`, then `scripts/integration-test.sh`. SIPp scenarios still
pending. Call-path verification meanwhile uses the pjsua local loop
(integration-test.sh tier 1).

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
