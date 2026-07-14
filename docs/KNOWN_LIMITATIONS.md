# Known limitations

Updated per release; honest by policy (never imply unimplemented features).

## As of Milestone 3 (2026-07-14)

- The UI is built and renders to the approved layout spec, but its
  **visual/interaction behaviors are not yet human-verified**: the
  floating incoming-call panel, menu-bar extra, VoiceOver pass, light
  mode, multi-monitor placement, and audio device switching are manual
  items in TESTING.md, all still "Not verified".
- Contacts tab exists but is intentionally empty (contacts land in M5).
- Auto-answer, call forwarding, and auto-conference indicators are
  deliberately absent from the status footer until those features exist
  (M4) — no controls that imply unimplemented functionality.
- Ring-device selection and audio hot-plug recovery are not implemented
  (input/output selection is).
- Dev builds are ad-hoc signed, so macOS asks for the login-keychain
  password on each rebuild (the Keychain ACL is bound to the binary's
  changing code identity). A stable dev signing identity fixes it;
  release builds are Developer ID signed and unaffected.

## As of Milestone 1 (2026-07-14)

- Registration, auth-failure detail, and PBX-routed calls with
  bidirectional media are verified against the Asterisk TestPBX
  (docs/INTEROP_TEST_MATRIX.md). Gaps that remain in the matrix:
  PBX→MacSIP inbound scenarios, DTMF read-back through the PBX, and SIPp
  scenario coverage.
- Account field set now covers the network-maturity set (transport incl.
  UDP+TCP auto, registration toggle/interval, outbound proxy, keepalive,
  session timers, contact/via rewrite, STUN/ICE/TURN, voicemail number,
  dial prefix). Still deferred to their own milestones: full dial-plan
  pattern language, presence publishing, caller-ID privacy, custom
  User-Agent/headers, local port overrides.
- STUN and TURN are implemented (config + Keychain TURN credential) but
  UNVERIFIED against real NAT infrastructure; ICE is verified on loopback
  only. TLS trusted-CA happy path untested (manual item).
- IPv6: UDP6/TCP6 transports are created and verified, but no end-to-end
  IPv6 call has been made — there is no local IPv6 peer (pjsua 2.17's CLI
  has no IPv6 option; the Dockerised Asterisk is IPv4-only).
- Network/sleep-wake recovery implemented; physical scenarios remain
  manual items (TESTING.md).
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
