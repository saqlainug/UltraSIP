# Source-reference and originality policy ("clean-room" document)

Status: **no clean-room separation is in effect, deliberately.** This
document exists (per SPEC) to record exactly what that means, what we may
and may not take from MicroSIP, and how each category of content in this
repository is derived.

## Legal basis

- UltraSIP is **GPLv3** (LICENSE).
- MicroSIP's source is **GPL-2.0-or-later** (verified from the official
  3.22.3 source archive headers — see docs/RESEARCH_BASELINE.md §1).
  GPL-2.0-or-later code may legally be studied, and even incorporated, in a
  GPLv3 work (one-way compatibility).
- Because reference is license-compatible, a clean-room (spec-writer /
  implementer separation) is unnecessary. CLAUDE.md records this decision;
  changing it (or the project license) is approval-gated.

## What is permitted vs forbidden

Permitted:
- Reading MicroSIP's published GPL source (3.22.3 is the newest published)
  to understand behavior, file formats (`microsip.ini` UTF-16LE INI,
  `Contacts.xml` schema), defaults, and workflows.
- Reimplementing observed behavior in original Swift/Obj-C++ code.
- Using public documentation (microsip.org/help), SIP standards (IETF
  RFCs), and PJSIP documentation.

Forbidden (regardless of license — trademark/asset hygiene, SPEC):
- The MicroSIP **name**, logos, icons, screenshots, or any image assets.
- Copyrightable UI text lifted verbatim from MicroSIP.
- Windows-specific implementation code (it wouldn't fit the architecture
  anyway) and registry behavior.
- Copying source without recording it (see ledger below): if any MicroSIP
  code is ever directly translated/adapted, it MUST be recorded in the
  ledger with file-level attribution, preserving its copyright notice —
  GPL compliance requires attribution, not just compatibility.

## Provenance categories

Every part of the repository falls into one of:

1. **Publicly documented behavior** — from microsip.org, PJSIP docs, RFCs,
   Apple docs. Recorded with sources in docs/RESEARCH_BASELINE.md.
2. **Observed interaction behavior** — behavior determined by running
   MicroSIP or examining its GPL source. Record observations in feature
   design notes / PARITY_MATRIX.md "MicroSIP reference" column.
3. **Independently designed implementation** — all UltraSIP code unless the
   ledger says otherwise. Original work, GPLv3.
4. **Third-party source** — pjproject + its bundled components
   (DEPENDENCY_LICENSES.md, THIRD_PARTY_NOTICES.md). Never copied into our
   tree; consumed via the pinned, checksum-verified build.
5. **Generated code** — Xcode-generated Info.plist content, build-script
   outputs under ThirdParty/ (never committed), and the arch-dispatch
   header shims produced by scripts/build-pjsip.sh.
6. **Original project assets** — any future icon/artwork must be original
   or properly licensed; provenance recorded here.

## Adapted-code ledger

Files containing code adapted from MicroSIP's GPL source (empty = none):

| UltraSIP file | MicroSIP source file / version | Nature of adaptation | Notice preserved |
|---|---|---|---|
| — | — | — | — |
