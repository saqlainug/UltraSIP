# Building MacSIP

## Requirements

- macOS 14+ host with **Xcode 26+** (Swift 6.2+ build settings are used).
  Deployment target of the produced app: macOS 13.
- Network access to github.com (pinned PJSIP source; checksum-verified).
- Nothing else: no Homebrew, cmake, or ninja. Formatting uses the
  toolchain-bundled `swift format`.

## First build

```
scripts/bootstrap.sh      # verifies tools; downloads + checksum-verifies PJSIP source
scripts/build-pjsip.sh    # builds universal static libpjproject.a (arm64 + x86_64)
scripts/build-debug.sh    # builds MacSIP.app (Debug, ad-hoc signed)
scripts/test.sh           # runs unit tests (XCTest)
```

PJSIP artifacts land in `ThirdParty/` (gitignored, reproducible —
`ThirdParty/pjsip/dist/BUILD_INFO.txt` records pin, flags, toolchain).
The PJSIP version pin + SHA-256 live in `scripts/build-pjsip.sh` and are
approval-gated — do not bump casually.

## Everyday commands (canonical — see CLAUDE.md)

| Command | Purpose |
|---|---|
| `scripts/build-debug.sh` | Debug build |
| `scripts/build-release.sh` | Release build, universal, lipo-verified |
| `scripts/build-universal.sh` | PJSIP + Release app in one pipeline |
| `scripts/test.sh` | unit tests |
| `scripts/integration-test.sh` | integration tests (needs TestPBX; exits 3 until Milestone 1 adds them) |
| `scripts/lint.sh` [`--fix`] | swift format lint + script syntax checks |
| `scripts/secret-scan.sh` | credential-shaped-content scan |
| `scripts/package.sh` | dist/ ZIP + DMG (unsigned unless sign.sh ran) |
| `scripts/sign.sh` / `scripts/notarize.sh` | Developer ID signing / notarization — require user-held credentials |
| `scripts/clean-generated.sh` [`--all`] | remove generated artifacts |

## Signing

Dev and CI builds are ad-hoc signed ("Sign to Run Locally") via
`Config/Project.xcconfig` — no credentials needed. Distribution requires
Developer ID + notarization (`scripts/sign.sh`, `scripts/notarize.sh`);
macOS 15+ has no Gatekeeper Control-click bypass, so unsigned distribution
is not viable.

## Troubleshooting

- **PJSIP checksum mismatch** — the script deletes the archive and refuses
  to build. Re-run once (transient corruption); if it persists, treat as a
  supply-chain red flag and stop.
- **`swift format` missing** — your Xcode is older than 26 / Swift 6; the
  toolchain bundles swift-format from Swift 6.0.
- **Test target fails with actor-isolation errors on XCTest initializers**
  — the test target must keep `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`
  (already set in the project; don't "fix" it to MainActor).
