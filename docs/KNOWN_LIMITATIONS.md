# Known limitations

Updated per release; honest by policy (never imply unimplemented features).

## As of Milestone 0 (2026-07-13)

- **No SIP functionality exists yet.** The app builds and shows a status
  placeholder; it cannot register, call, or receive. See PARITY_MATRIX.md
  for the complete feature-by-feature status.
- PJSIP 2.17 upstream has nine unpatched security advisories
  (THREAT_MODEL.md T3); acceptable only because nothing is network-exposed
  yet — must be resolved before Milestone 1 touches untrusted networks.
- DTLS-SRTP is not possible with the current TLS backend (Apple
  Network.framework); decision scheduled for Milestone 2
  (docs/PJSIP_INTEGRATION.md).
- The PJSIP build is audio-only (video disabled) by design until
  Milestone 6.
- CI has not yet run on GitHub infrastructure (workflow exists; the
  `macos-26` runner label must be validated on first push).
- MicroSIP call-log import will be limited: MicroSIP ≥ 3.22.5 stores the
  call log in an undocumented database and publishes no matching source.
- No app icon yet (original artwork pending; MicroSIP assets are off-limits).
