# CLAUDE.md — UltraSIP

Native, open-source macOS softphone with functional parity to MicroSIP for Windows (stable release), built on PJSIP/PJSUA2. Real SIP/RTP — no mocks, no simulated dialing, no UI-only prototypes.

**This file is operating rules only.** The full specification is `docs/SPEC.md` — authoritative for features, security, testing, and acceptance criteria. Never implement a feature from memory of the spec; open the relevant SPEC.md section first. Parity status lives in `PARITY_MATRIX.md`.

## Project facts

- Product `UltraSIP` · repo `ultrasip` · bundle id `com.ultranet.ultrasip` (all configurable via `Config/Project.xcconfig` — never hardcode)
- macOS 13+, universal (arm64 + x86_64), Hardened Runtime, Developer ID distribution (Mac App Store: out of scope unless sandboxing is separately verified)
- Swift 5.9+ · SIP stack: pinned PJSIP/PJSUA2 release (see `scripts/build-pjsip.sh` for version + SHA-256)

## License posture (decided — do not revisit without user approval)

- Project license: **GPLv3** (PJSIP GPL build; no commercial PJSIP license).
- Reading MicroSIP's GPL source for behavior/logic reference is **permitted**. Copying its name, trademarks, icons, images, or other assets is **forbidden**. No clean-room process is in effect.
- Every new dependency/codec goes through the `dependency-review` skill and `licensing-reviewer` agent before adoption; record in `DEPENDENCY_LICENSES.md` + `THIRD_PARTY_NOTICES.md`. Note: G.729 patents expired 2017 — evaluate bcg729; do not bundle AMR/SILK without confirmed terms.

## Human approval gates (hard stops — do not proceed past these without explicit user sign-off)

1. After Milestone 0: research baseline + architecture + this file's command set.
2. Before Milestone 3 UI build-out: one-page UI layout spec (window sizes, control placement, tab structure).
3. Any change to: project license, PJSIP version, bundle/signing identity, or public IPC surface.

## Architecture (summary — details in ARCHITECTURE.md)

Layered; protocol boundaries between layers. PJSIP types never escape SIPCore.

- `SIPCore/` — Obj-C++ bridge + engine + state machines. Owns all PJSIP objects; emits immutable Swift event values.
- `Domain/` — pure Swift models + logic; unit-testable with no SIP server.
- `Features/` + `Shared/` — UI. **AppKit-primary** for: main window chrome, incoming-call NSPanel, menu bar, Preferences, Call Manager. SwiftUI allowed inside AppKit-hosted content views. Rationale: compact fixed-density utility window (~360×560pt), cross-Spaces floating panel, precise focus/keyboard behavior.
- `Persistence/` — repositories, versioned schema, tested migrations. No password columns.
- `Platform/` — audio/video devices, notifications, menu bar, Contacts, URL handling, XPC/local IPC, launch-at-login.

## Canonical commands (use these; do not invent variants)

```
scripts/bootstrap.sh          # tool checks + fetch/verify pinned deps
scripts/build-pjsip.sh        # reproducible universal static PJSIP (checksum-verified)
scripts/build-debug.sh        # xcodebuild Debug
scripts/build-release.sh      # xcodebuild Release, universal
scripts/test.sh               # unit tests (XCTest)
scripts/integration-test.sh   # requires test PBX up (see below)
scripts/lint.sh               # format + lint; run before every commit
scripts/package.sh            # DMG/ZIP; sign.sh / notarize.sh need user-held credentials — always ask
TestPBX/: docker compose up -d   # local Asterisk/FreeSWITCH; see docs/TEST_PBX.md
```

CI reality: GitHub macOS runners cannot run Docker. CI = build + unit tests + lint + secret scan on macOS. Integration tests run locally or on a self-hosted runner and are marked environment-dependent — never fake them green in CI.

## SIP threading rules (violations cause intermittent crashes — read every session)

1. All PJSIP calls go through the single serialized SIP execution context in `SIPCore/Engine/`. Nowhere else. Never from the main thread; never blocking on the main thread.
2. **`pj_thread_register` trap:** any pthread touching PJSIP must be registered first. Swift actors and plain GCD queues do NOT guarantee stable thread identity. Use the dedicated serial DispatchQueue whose underlying thread is registered (or defensively register-on-first-use per thread). Do not assume actor executors map to stable pthreads.
3. PJSIP callbacks arrive on PJSIP threads: convert to immutable event values, hop to the SIP context for engine mutation, publish to UI via `@MainActor`. Never mutate observable UI state directly from a callback.
4. Guard against stale/duplicate callbacks after disconnect; explicit ownership + guarded teardown ordering (calls → accounts → transports → endpoint) to prevent use-after-free during shutdown.

## Coding rules

- Swift: no force-unwraps/`try!` in Domain/SIPCore without a documented invariant; no silent error swallowing; typed errors across the bridge.
- Obj-C++ bridge: explicit ownership documented per class; translate C++ exceptions to NSError/Swift errors; never return PJSIP-owned buffers or ambiguous-lifetime pointers.
- Files ≲400 lines; prefer small testable types; protocol-first at layer boundaries.
- Scripts: strict mode (`set -euo pipefail`), quote variables, resolve repo root safely, fail with actionable messages, write only inside documented directories.

## Security rules (non-negotiable defaults)

- Secrets (SIP passwords, TURN creds, directory tokens): **Keychain only**; DB stores stable Keychain references; never plaintext, never displayed back on edit, never in logs/exports (encrypted export is explicit opt-in per SPEC §21).
- TLS: system trust, hostname verification ON. Insecure override is per-account, visible, default-off. Never disable validation to "fix" a test.
- Redaction: Authorization/digest data, DTMF sequences, and message bodies redacted in logs and diagnostics; redaction has automated tests — extend them when adding log sites.
- Inputs: validate + bound SIP URIs, imports (schema + transactional + rollback), directory responses (size/depth limits, **no XXE**), filenames (sanitized, collision-safe). No execution of received content; no automatic URL opening.
- Shortcut executable actions: path + argv array only (no shell strings), disabled by default, user-approved, never receive credentials.
- Local control surface: XPC or permission-checked Unix socket only. No network control port.

## MicroSIP migration (required feature — do not drop)

Import MicroSIP-for-Windows `Contacts.xml` and `microsip.ini` (accounts sans passwords + settings mapping). Track in PARITY_MATRIX.md; round-trip tests required.

## Session discipline

**Start:** read this file → `git status` → current milestone + relevant PARITY_MATRIX rows → relevant SPEC.md section → related tests → state the vertical slice being attempted. Use Plan mode for multi-module work. Don't load unrelated files.

**Feature loop (vertical slices only — no parallel stub farms):** research → state machine (`docs/SIP_STATE_MACHINES.md`) → domain model → bridge → persistence → UI → redacted logging → unit tests → integration tests → build → run tests → review diff → update docs + PARITY_MATRIX → commit.

**End:** build + relevant tests → `git diff` review → `/review` (+ `/security-review` for security-sensitive changes) → update PARITY_MATRIX.md → leave repo buildable → report per SPEC "Final session report", with **exact** command output.

## Definition of done (per feature)

Implemented ≠ done. Done = unit tests pass + integration test against TestPBX passes (or documented environment-dependent skip) + **media verified where applicable** (bidirectional RTP/correct codec/DTMF delivery — a 200 OK is not a working call) + docs + PARITY_MATRIX updated with correct graduated status + no new lint/analyzer warnings. Never mark complete from a compiled interface. Never fabricate test results — report failures verbatim with the command that produced them and a classified cause (code / environment / dependency / license / credential / platform).

## Git workflow

Small logical commits as durable checkpoints (do not rely on session history). Imperative messages referencing the slice. Never commit: secrets, `.env`, keys, provisioning profiles, opaque prebuilt binaries (PJSIP artifacts are reproducible via script, gitignored). No `git push --force`. Baseline commit before any large refactor.

## Do not edit casually

- `scripts/build-pjsip.sh` pin/checksum/flags (version changes = approval gate)
- `Persistence/Migrations/` (append-only; never rewrite shipped migrations)
- `Security/` (changes require `/security-review` + security-reviewer agent pass)
- Generated PJSIP build artifacts (regenerate, never hand-edit)
- `Config/Project.xcconfig` identity values, `LICENSE`, notice files

## Known environment constraints

- Signing/notarization require user-held credentials — always ask before `sign.sh`/`notarize.sh`.
- Docker only for TestPBX; approval required for image downloads.
- Bluetooth/USB headset behavior and multi-monitor panel placement are manual-test items (`TESTING.md`) — never claim them verified from CI.
