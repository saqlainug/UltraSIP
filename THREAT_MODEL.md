# MacSIP threat model

Living document; every security-relevant feature updates it (with
`/security-review` + security-reviewer agent per CLAUDE.md). Status column
is honest: at Milestone 0 almost nothing is implemented, so most rows are
"design mandate" — the mitigation the implementation MUST ship with.

## Assets

SIP credentials (passwords, TURN credentials, directory tokens) ·
call/message content and metadata (history DB, messages, recordings) ·
contact data · device identity/availability (registration state) · the
user's microphone and camera · local machine integrity (IPC surface,
shortcut executable actions).

## Trust boundaries

1. App ↔ SIP network (registrar/proxy/peers — partially or fully untrusted)
2. App ↔ RTP media path (untrusted)
3. App ↔ external directory servers (semi-trusted HTTPS)
4. App ↔ imported files (untrusted)
5. App ↔ local IPC clients / URL-scheme callers (semi-trusted local)
6. App ↔ its own persisted state (protected by macOS user boundary)
7. Build ↔ upstream dependency supply chain

## Threats and mitigations

| # | Threat | Mitigation | Status (2026-07-13) |
|---|---|---|---|
| T1 | SIP credential theft (disk) | Keychain-only storage; DB/exports hold opaque Keychain refs; no plaintext export unless explicit passphrase-encrypted opt-in (SPEC §21) | Design mandate (M1 Keychain store) |
| T2 | Credential leakage via logs/diagnostics | LogRedactor on every sink; Authorization/digest/DTMF/message bodies redacted; automated redaction tests extended per new log site | Design mandate (M1) |
| T3 | Malformed SIP messages (parser memory safety) | Pinned PJSIP kept current on advisories; **open exposure: nine advisories affect ≤2.17 with no patched release, incl. CVE-2026-57161 (HIGH, stack overflow in Service-Route handling on the REGISTER-response path)**. Re-checked **2026-07-14** (GitHub releases API): 2.17 still latest, no 2.17.1. Posture decision: development remains TestPBX/local-peer-only; the M2 TCP/TLS listeners do not change that (no distribution, no untrusted registrar use). HARD GATE before first release or any untrusted-network use: 2.17.1 bump or cherry-picked fixes (pin change = approval gate 3). | **Open — tracked (re-checked 2026-07-14)** |
| T4 | SIP URI injection / header injection from user input | Domain-level URI validation + bounding before the bridge; no string-concatenated SIP headers; custom headers validated | Design mandate |
| T5 | TLS downgrade / certificate bypass | System trust + hostname verification default-on; insecure override per-account, visible, default-off, never global; no validation disabling in tests | Design mandate (M2) |
| T6 | Malicious directory data (XXE, oversized responses, entity bombs) | XML parsing with external entities disabled; response size/depth limits; timeouts; backoff; no auth tokens in logs | Design mandate (M5) |
| T7 | Malicious import files | Schema validation, size bounds, transactional apply + rollback, preview before apply | Design mandate (M5/M7) |
| T8 | Command injection via shortcut executable actions | argv-array execution only (no shell strings); disabled by default; explicit user approval; never receive credentials; redacted logging | Design mandate (M5) |
| T9 | Local IPC abuse (dial/hangup/exfil by other local processes) | XPC or permission-checked Unix socket; no network control port; command allowlist; confirmation for destructive ops | Design mandate (M7) |
| T10 | Recording/history/DB leakage | Files under user-only permissions; sanitized collision-safe filenames; recording-consent notice; bounded retention options | Design mandate (M4) |
| T11 | Path traversal / symlink attacks on recordings & exports | SecureFileWriter: sanitized names, O_NOFOLLOW-style checks, writes only inside chosen directories | Design mandate (M4) |
| T12 | Oversized/flooded calls & messages (DoS) | maxConcurrentCalls with auto-reject; bounded message sizes; rate limits on IPC | Design mandate (M4/M7) |
| T13 | Caller-ID spoofing / untrusted asserted identity | Display P-Asserted-Identity/RPID distinctly from From:; never auto-trust auto-answer headers across untrusted networks without configurable policy (SPEC §8) | Design mandate (M4) |
| T14 | Dependency compromise (supply chain) | Pinned versions + SHA-256 verified on every fetch (build fails hard on mismatch and says so); no `curl \| sh`; no opaque binaries in git; dependency-review skill for every addition | **Implemented** (scripts/build-pjsip.sh) for PJSIP; process in place |
| T15 | Update-channel compromise (future updater) | Update checking opt-in; signed+notarized artifacts; HTTPS with validation; no auto-execution | Design mandate (M7) |
| T16 | Obj-C++ bridge memory-safety (use-after-free in callbacks, shutdown races) | Ownership documented per class; calls destroyed per PJSUA2 lifecycle rules; stale callbacks dropped by ID; teardown order calls→accounts→transports→endpoint; reconfiguration refused while calls are live. **Verified 2026-07-14: TSan clean (no data races) and ASan clean (no use-after-free) across the full tier-1 call lifecycle** — plus the 10 security-review findings fixed. | **Implemented + sanitizer-verified** |
| T17 | Microphone/camera misuse or surprise activation | OS permission prompts (usage descriptions + Hardened Runtime entitlements present); auto-answer plays audible warning before mic activation (SPEC §8); visible active state | Entitlements/descriptions **implemented**; behavior M4 |
| T18 | Secrets committed to repo | scripts/secret-scan.sh in CI + release-check; .gitignore covers env/keys/profiles; Keychain-only rule | **Implemented** (CI + script) |

## Secure defaults (SPEC "Security" — enforced as review checklist)

Keychain secrets · TLS validation on · no executable hooks · no analytics ·
crash reporting opt-in · update checking opt-in · DTMF + message redaction ·
bounded inputs · sanitized filenames · strict imports · no automatic URL
opening · no execution of received content.

## Review cadence

- Every SIPCore/Security/Persistence-touching change: security-reviewer
  agent (read-only) + `/security-review` for sensitive diffs.
- Every milestone completion: full pass over this table, statuses updated
  with evidence, new threats added.
- Every PJSIP advisory check: recorded here with date (last: 2026-07-13,
  nine open — see T3).
