# Contributing

Thanks for your interest! Ground rules, kept short:

- **License**: contributions are accepted under GPLv3. By submitting a PR
  you agree to license your work under the project license.
- **No MicroSIP assets**: reading MicroSIP's GPL source for behavior is
  fine; contributing its name, icons, artwork, or verbatim UI text is not
  (docs/CLEAN_ROOM_PROCESS.md — and record any adapted GPL code in its
  ledger).
- **Real functionality only**: no mock dialers, no stub features presented
  as working. PARITY_MATRIX.md statuses must match reality; a SIP 200 OK
  is not a working call (media must be verified).
- **Vertical slices**: features land whole — domain model, bridge,
  persistence, UI, redacted logging, tests, docs, parity row — per
  `.claude/skills/sip-feature-slice/SKILL.md`.
- **Before every PR**: `scripts/lint.sh && scripts/build-debug.sh &&
  scripts/test.sh` all green; `scripts/secret-scan.sh` clean; never commit
  secrets, `.env`, keys, or prebuilt binaries.
- **Threading rules are law**: read CLAUDE.md "SIP threading rules" before
  touching SIPCore. Violations cause intermittent crashes that burn weeks.
- **Dependencies**: none without the dependency-review checklist
  (`.claude/skills/dependency-review/SKILL.md`) and updated license records.
- **Security-sensitive changes** (Security/, credentials, TLS, imports,
  IPC): expect a security review pass; update THREAT_MODEL.md in the same
  change.

Build instructions: BUILDING.md. Architecture: ARCHITECTURE.md.
