# Known limitations

Updated per release; honest by policy (never imply unimplemented features).

## As of Milestone 1 (2026-07-14)

- Registration, auth-failure detail, and PBX-routed calls with
  bidirectional media are verified against the Asterisk TestPBX
  (docs/INTEROP_TEST_MATRIX.md). Gaps that remain in the matrix:
  PBX→MacSIP inbound scenarios, DTMF read-back through the PBX, and SIPp
  scenario coverage.
- Single account only (multiple accounts + switching = later M2 slice).
- TLS trusted-CA happy path untested (validation-rejects and override
  paths are integration-tested; a trusted-CA run needs a CA installed in
  the system keychain — manual item). UDP+TCP combined mode and IPv6
  pending. STUN/TURN/ICE and network/sleep-wake recovery pending (M2).
- TestPBX Asterisk image lacks res_srtp — PBX-side SRTP blocked until an
  SRTP-capable image passes dependency-review (endpoint config ready).
- Mic mute is implemented but has no media-level automated assertion yet;
  remote-output mute not implemented.
- DTMF is RFC 4733 only (INFO/in-band + preference setting pending).
- UI is functional but deliberately unpolished pre-gate-2 (in-window
  incoming banner, no floating panel/menu bar/dialpad grid yet).
- No ringtone/sound events yet; no dial plan/prefix transformation yet.
- History: M1 subset (no filters/search/export yet).
- PJSIP 2.17 upstream has nine unpatched security advisories
  (THREAT_MODEL.md T3); acceptable only because nothing is network-exposed
  yet — must be resolved before Milestone 1 touches untrusted networks.
- DTLS-SRTP is **permanently out of scope by decision** (2026-07-13): it
  would require the OpenSSL backend; MacSIP ships SDES-SRTP as its media
  encryption (docs/PJSIP_INTEGRATION.md).
- The PJSIP build is audio-only (video disabled) by design until
  Milestone 6.
- CI has not yet run on GitHub infrastructure (workflow exists; the
  `macos-26` runner label must be validated on first push).
- MicroSIP call-log import will be limited: MicroSIP ≥ 3.22.5 stores the
  call log in an undocumented database and publishes no matching source.
- No app icon yet (original artwork pending; MicroSIP assets are off-limits).
