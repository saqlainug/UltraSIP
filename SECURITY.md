# Security policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately to the maintainer
(repository owner) rather than opening a public issue. Include: affected
version/commit, reproduction steps, and impact. You should receive an
acknowledgment within 7 days. Coordinated disclosure preferred.

## Scope and posture

MacSIP handles SIP credentials, call/message content, and microphone/camera
access. The security design is documented in [THREAT_MODEL.md](THREAT_MODEL.md);
non-negotiable defaults (from CLAUDE.md):

- Secrets live only in the macOS Keychain; the database stores opaque
  references; secrets never appear in logs, diagnostics, or default exports.
- TLS uses system trust with hostname verification on; any insecure
  override is per-account, visible, and off by default.
- Logs and diagnostics redact authorization data, DTMF, and message bodies
  — with automated tests.
- All external inputs (SIP URIs, imports, directory responses) are bounded
  and validated; XML is parsed with external entities disabled.
- No network control port; local automation only via XPC / permission-
  checked Unix socket.
- Dependencies are version-pinned with SHA-256 verification
  (`scripts/build-pjsip.sh`); upstream security advisories are tracked in
  THREAT_MODEL.md (T3) with dates.

## Known upstream exposure

As of 2026-07-13, pjproject ≤ 2.17 has nine unpatched public advisories
(fixes on master only). MacSIP is pre-release and not yet network-exposed;
the pin will be updated (or fixes cherry-picked) before any release that
talks to untrusted networks. Status: THREAT_MODEL.md T3.
