# Interoperability test matrix

Statuses: Not tested · Pass · Partial · Fail · Blocked. Every Pass/Fail
cites the run (script + date). Never claim untested interoperability
(SPEC "Interoperability matrix").

Peers/infrastructure vs scenario, as of **2026-07-13**:

| Scenario | pjsua 2.17 (local loop, UDP) | Asterisk 20 (TestPBX) | FreeSWITCH | Hosted PBX |
|---|---|---|---|---|
| Outgoing call + bidirectional RTP | **Pass** (integration-test.sh tier 1, 2026-07-13; RTP counters both ways) | Blocked¹ | Not tested | Not tested |
| Incoming call + answer + RTP | **Pass** (tier 1, 2026-07-13) | Blocked¹ | Not tested | Not tested |
| Reject as busy (486 at peer) | **Pass** (tier 1, 2026-07-13) | Blocked¹ | Not tested | Not tested |
| DTMF RFC 4733 delivery | **Pass** (tier 1, 2026-07-13; peer log assertion) | Blocked¹ | Not tested | Not tested |
| Hold / resume (re-INVITE) | **Pass** (tier 1, 2026-07-13; state assertions) | Blocked¹ | Not tested | Not tested |
| Registration + digest auth | Not applicable (pjsua is not a registrar) | Blocked¹ | Not tested | Not tested |
| Wrong-password failure detail | Not applicable | Blocked¹ | Not tested | Not tested |
| Voicemail, feature codes, pickup | Not applicable | Blocked¹ | Not tested | Not tested |
| TCP / TLS / SRTP | Not tested (M2) | Blocked¹ | Not tested | Not tested |
| Audible echo-test media (600) | Not tested (RTP counters only so far) | Blocked¹ | Not tested | Not tested |

¹ **Blocked (environment):** Docker is not installed on the primary dev
machine, so the TestPBX (TestPBX/docker-compose.yml, config written) has
never run. Unblock: install Docker Desktop/OrbStack, approve the Asterisk
image download, `cd TestPBX && docker compose up -d`, then
`scripts/integration-test.sh`.

Platform coverage of the local-loop passes: Apple Silicon (arm64) only —
the dev machine. Intel, USB/Bluetooth audio devices: Not tested
(TESTING.md manual items).
