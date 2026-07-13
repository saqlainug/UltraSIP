---
name: sip-feature-slice
description: Mandatory vertical-slice procedure for implementing any SIP feature (registration, calls, hold, transfer, conference, DTMF, presence, messaging, etc.). Enforces the CLAUDE.md feature loop end-to-end — never build stub farms or UI-only features.
---

# SIP feature slice

Every SIP feature is implemented as ONE vertical slice, completed and
verified before the next begins (SPEC "Implementation behavior"). No parallel
half-features. Complete these steps in order:

## 1. Research
Open the relevant SPEC.md section (never from memory). Check PARITY_MATRIX.md
current status + MicroSIP baseline behavior (docs/RESEARCH_BASELINE.md).
For PJSIP API semantics use docs.pjsip.org and the pinned source under
ThirdParty/pjsip/src-arm64/. Delegate open design questions to the
sip-architect agent.

## 2. State machine
Add/update the feature's state machine in docs/SIP_STATE_MACHINES.md:
states, events, transitions, error edges, timeout edges, race guards
(e.g. user hangs up mid-answer). Implementation must match the diagram.

## 3. Domain model
Pure Swift in `MacSIP/Domain/` — immutable values, typed errors, no PJSIP
types, no I/O. Unit-testable without a SIP server.

## 4. Bridge
`MacSIP/SIPCore/` Obj-C++ only. Follow the threading rules (CLAUDE.md —
serialized SIP context, pj_thread_register, callbacks → immutable events →
MainActor). Document ownership per class. Typed errors across the boundary.

## 5. Persistence (if the feature stores data)
Repository protocol in Domain, implementation in `MacSIP/Persistence/`.
Schema change ⇒ new append-only migration + migration test. No password
columns, ever.

## 6. UI
Feature view in `MacSIP/Features/<Feature>/`. Compact (SPEC "Minimalist
macOS UI"), keyboard-navigable, VoiceOver labels, honest states (no dead
controls). AppKit-primary shell rules per ARCHITECTURE.md.

## 7. Redacted logging
OSLog with privacy annotations. DTMF, credentials, digest data, message
bodies are redacted — and the redaction test suite is extended for every
new log site (Security/LogRedactor).

## 8. Tests
- Unit: state machine transitions incl. error/timeout edges, domain logic.
- Integration: TestPBX scenario for success + at least rejection/timeout
  (see interoperability-test skill). Media-touching features need media
  verification, not just signaling.

## 9. Verify + record
Run the build-and-verify skill sequence. Update PARITY_MATRIX.md with the
correct graduated status (Implemented / Unit tested / Integration tested —
never overstate), docs, and commit with an imperative message naming the
slice.

## Definition of done
CLAUDE.md applies: implemented ≠ done. A 200 OK is not a working call.
