---
name: interoperability-test
description: Procedure for running MacSIP integration/interoperability tests against the local TestPBX — starting the PBX, provisioning extensions, running SIPp scenarios, verifying media in both directions, and recording results in the interop matrix.
---

# Interoperability test

Environment-dependent: needs Docker (never available on GitHub-hosted macOS
runners — do not wire into CI). Docker image downloads require user approval.

## 1. Start the TestPBX

```
cd TestPBX && docker compose up -d && docker compose ps
```

Details + extension plan: docs/TEST_PBX.md. Wait until the PBX container
reports healthy; `docker compose logs -f` on first start.

> Milestone 0 status: TestPBX/ is empty; the compose file, PBX config, and
> SIPp scenarios arrive with Milestone 1. Until then this skill documents
> the procedure only — there is nothing to run yet.

## 2. Provision test extensions

The PBX config (checked into TestPBX/) defines at least three local test
extensions plus voicemail, transfer, conference, presence/BLF, and pickup
feature codes. Test credentials live ONLY in TestPBX/ config — they are
local-only, throwaway, and must never be real/customer credentials.

## 3. Run scenarios

- App-level integration tests: `scripts/integration-test.sh`
- SIPp scenarios (registration/auth/404/486/timeout/cancel/early media/
  DTMF/re-registration/malformed input/transfer): kept under
  TestPBX/sipp/; invoke per docs/TEST_PBX.md.

## 4. Verify media — signaling green is NOT enough

For every call scenario confirm ALL of:
- RTP flows in BOTH directions (packet counters move on both ends)
- negotiated codec is the expected one
- audible test audio arrives both ways (tone/fixture, not silence)
- DTMF digits arrive (check PBX-side detection log)
- hold stops/resumes media as configured
- SRTP state matches the account's media-encryption policy
- recordings (if in scenario) are playable files

## 5. Capture sanitized logs

Redact before committing or pasting into docs: credentials, Authorization/
digest headers, full DTMF sequences, message bodies. Keep raw captures out
of git.

## 6. Record results

Update docs/INTEROP_TEST_MATRIX.md: one row per scenario × transport ×
server, status ∈ {Not tested, Pass, Partial, Fail, Blocked}, with date and
the exact command used. Downgrades are recorded as readily as upgrades.
Failures: quote output verbatim and classify cause (code / environment /
PBX limitation) — flaky RTC tests usually mean a threading bug, not a
retry candidate.
