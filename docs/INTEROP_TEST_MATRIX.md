# Interoperability test matrix

Statuses: Not tested · Pass · Partial · Fail · Blocked. Every Pass/Fail
cites the run (script + date). Never claim untested interoperability
(SPEC "Interoperability matrix").

Peers/infrastructure vs scenario, as of **2026-07-14**:

| Scenario | pjsua 2.17 (local loop, UDP) | Asterisk 20.5.2 (TestPBX, Docker, UDP) | FreeSWITCH | Hosted PBX |
|---|---|---|---|---|
| Registration + digest auth (expiry reported) | Not applicable (no registrar) | **Pass** (integration-test.sh tier 2, 2026-07-14) | Not tested | Not tested |
| Wrong-password failure detail (401 → "Authentication required") | Not applicable | **Pass** (tier 2, 2026-07-14) | Not tested | Not tested |
| Outgoing call + bidirectional RTP | **Pass** (tier 1, 2026-07-13; RTP counters both ways) | **Pass** via echo app, digest-challenged INVITE, PBX-relayed RTP (tier 2, 2026-07-14) | Not tested | Not tested |
| Incoming call + answer + RTP | **Pass** (tier 1, 2026-07-13) | Not tested (PBX→MacSIP dial pending SIPp/second-client scenario) | Not tested | Not tested |
| Reject as busy (peer sees 486) | **Pass** (tier 1, 2026-07-13) | Not tested (inbound direction) | Not tested | Not tested |
| Failure outcomes: 486 → "Busy", 404 → "Number not found" | Not applicable | **Pass** (tier 2, 2026-07-14; dialplan generators) | Not tested | Not tested |
| DTMF RFC 4733 delivery | **Pass** (tier 1, 2026-07-13; peer log assertion) | Not tested (602 read-back scenario pending) | Not tested | Not tested |
| Hold / resume (re-INVITE) | **Pass** (tier 1, 2026-07-13) | Not tested | Not tested | Not tested |
| Voicemail, feature codes, pickup | Not applicable | Not tested (dialplan ready) | Not tested | Not tested |
| TCP / TLS / SRTP | Not tested (M2) | Not tested (TCP transport configured; TLS pending M2) | Not tested | Not tested |

Environment notes: TestPBX runs in Docker (image `andrius/asterisk:
alpine-20.5.2`); the UDP path through Docker's proxy drops oversized SIP
datagrams — MacSIP's compact default SDP (PCMU/PCMA/G722 only, MicroSIP
parity) keeps INVITEs under the RFC 3261 UDP threshold. Asterisk transport
uses external_media/signaling_address=127.0.0.1 because of container NAT.

Platform coverage: Apple Silicon (arm64) dev machine only. Intel,
USB/Bluetooth audio devices: Not tested (TESTING.md manual items).
