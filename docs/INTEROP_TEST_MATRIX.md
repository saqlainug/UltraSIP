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
| Incoming call + answer + RTP | **Pass** (tier 1, 2026-07-13) | Not tested (PBX→UltraSIP dial pending SIPp/second-client scenario) | Not tested | Not tested |
| Reject as busy (peer sees 486) | **Pass** (tier 1, 2026-07-13) | Not tested (inbound direction) | Not tested | Not tested |
| Failure outcomes: 486 → "Busy", 404 → "Number not found" | Not applicable | **Pass** (tier 2, 2026-07-14; dialplan generators) | Not tested | Not tested |
| DTMF RFC 4733 delivery | **Pass** (tier 1, 2026-07-13; peer log assertion) | Not tested (602 read-back scenario pending) | Not tested | Not tested |
| Hold / resume (re-INVITE) | **Pass** (tier 1, 2026-07-13) | Not tested | Not tested | Not tested |
| Voicemail, feature codes, pickup | Not applicable | Not tested (dialplan ready) | Not tested | Not tested |
| TCP registration | Not applicable | **Pass** (tier 2, 2026-07-14) | Not tested | Not tested |
| TLS: untrusted cert rejected by default | Not applicable | **Pass** (tier 2, 2026-07-14; self-signed CA refused, no registration) | Not tested | Not tested |
| TLS: per-account insecure override registers (encrypted signaling) | Not applicable | **Pass** (tier 2, 2026-07-14) | Not tested | Not tested |
| TLS: trusted-CA happy path | Not applicable | Not tested (needs CA installed in system trust — manual item) | Not tested | Not tested |
| SDES-SRTP mandatory, encrypted media both ways | **Pass** (tier 1, 2026-07-14; ↔ pjsua --use-srtp=2) | **Blocked** — image lacks res_srtp (488s all SAVP; endpoint 103 config ready for an SRTP-capable image) | Not tested | Not tested |
| SRTP mandatory vs plain endpoint: no cleartext fallback | Not tested | **Pass** (tier 2, 2026-07-14; 488, never connected) | Not tested | Not tested |
| Account switch without restart (re-register + call as new identity) | Not applicable | **Pass** (tier 2, 2026-07-14) | Not tested | Not tested |
| ICE-enabled call, media both ways | Not tested | **Pass** (tier 2, 2026-07-14; ice_support=yes, loopback candidates) | Not tested | Not tested |
| STUN / TURN against real NAT infra | Not applicable | Not testable locally — needs external STUN/TURN (or a future coturn container) | Not tested | Not tested |
| IPv6 transports created (UDP6/TCP6) | **Pass** (tier 1, 2026-07-14; engine diagnostics) | n/a | n/a | n/a |
| IPv6 end-to-end call | **Blocked** — no local IPv6 peer: pjsua 2.17 CLI has no IPv6 option and the Dockerised Asterisk is IPv4-only | **Blocked** (same) | Not tested | Not tested |
| Sanitizers over full call lifecycle | **Pass** — TSan clean (no data races) and ASan clean (no use-after-free), tier-1 suite, 2026-07-14 | n/a | n/a | n/a |

Environment notes: TestPBX runs in Docker (image `andrius/asterisk:
alpine-20.5.2`); the UDP path through Docker's proxy drops oversized SIP
datagrams — UltraSIP's compact default SDP (PCMU/PCMA/G722 only, MicroSIP
parity) keeps INVITEs under the RFC 3261 UDP threshold. Asterisk transport
uses external_media/signaling_address=127.0.0.1 because of container NAT.

Platform coverage: Apple Silicon (arm64) dev machine only. Intel,
USB/Bluetooth audio devices: Not tested (TESTING.md manual items).
