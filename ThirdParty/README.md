# ThirdParty/

Generated third-party build artifacts. Everything here except this README is
**gitignored and reproducible** — never hand-edit, never commit binaries.

- `cache/` — pinned, checksum-verified source archives
  (pjproject tarball; SHA-256 enforced by `scripts/build-pjsip.sh`)
- `pjsip/src-<arch>/` — per-arch PJSIP build trees
- `pjsip/dist/<arch>/` — per-arch install prefixes + build logs
- `pjsip/dist/universal/` — lipo'd `lib/libpjproject.a` + merged headers
  (what the Xcode project links against, starting Milestone 1)
- `pjsip/dist/BUILD_INFO.txt` — pin + flags + toolchain reproducibility record

Rebuild everything: `scripts/build-pjsip.sh --force`
Remove everything: `scripts/clean-generated.sh`

The PJSIP version pin lives in `scripts/build-pjsip.sh` and is
approval-gated (CLAUDE.md gate 3).
