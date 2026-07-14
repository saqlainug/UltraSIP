#!/usr/bin/env bash
# build-pjsip.sh — reproducible universal static PJSIP build.
#
# Pinned version + SHA-256 below. CHANGING THE PIN IS APPROVAL-GATED
# (CLAUDE.md gate 3): do not bump without explicit user sign-off.
#
# Output (all inside ThirdParty/ — gitignored, regenerate, never hand-edit):
#   ThirdParty/cache/pjproject-<ver>.tar.gz     verified source archive
#   ThirdParty/pjsip/src-<arch>/                per-arch build trees
#   ThirdParty/pjsip/dist/<arch>/               per-arch install prefix
#   ThirdParty/pjsip/dist/universal/lib/libpjproject.a
#   ThirdParty/pjsip/dist/universal/include/    merged headers
#   ThirdParty/pjsip/dist/BUILD_INFO.txt        reproducibility record
#
# Flags: --fetch-only (download+verify, no build)
#        --force      (rebuild even if BUILD_INFO matches)
#        --clean      (remove ThirdParty/pjsip before building)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
assert_repo_root

# ---- Pin (approval-gated; see header) --------------------------------------
PJSIP_VERSION="2.17"
PJSIP_URL="https://github.com/pjsip/pjproject/archive/refs/tags/${PJSIP_VERSION}.tar.gz"
PJSIP_SHA256="065fe06c06788d97c35f563796d59f00ce52fe9558a52d7b490a042a966facce"
# bcg729 (G.729A/B, GPLv3, Belledonne) — dependency-review recorded in
# DEPENDENCY_LICENSES.md. Compiled per-arch with clang directly (pure
# ANSI C; avoids a cmake dependency) and linked into PJSIP.
BCG729_VERSION="1.1.1"
BCG729_URL="https://github.com/BelledonneCommunications/bcg729/archive/refs/tags/${BCG729_VERSION}.tar.gz"
BCG729_SHA256="68599a850535d1b182932b3f86558ac8a76d4b899a548183b062956c5fdc916d"
MACOS_MIN="13.0"
ARCHS=(arm64 x86_64)
# Milestone 0 baseline: audio-only, native Apple TLS backend, bundled SRTP,
# built-in codecs only (G.711/G.722/GSM/iLBC/Speex/L16/G.722.1). Opus, video
# codecs, and DTLS-SRTP backend decisions are later-milestone changes that go
# through dependency-review and re-pin here.
CONFIGURE_FLAGS=(
  --disable-video
  --disable-ffmpeg
  --disable-openh264
  --disable-vpx
  --disable-v4l2
  --disable-sdl
  --disable-opus
  --disable-opencore-amr
)
# -----------------------------------------------------------------------------

THIRD_PARTY="${REPO_ROOT}/ThirdParty"
CACHE_DIR="${THIRD_PARTY}/cache"
PJSIP_DIR="${THIRD_PARTY}/pjsip"
DIST_DIR="${PJSIP_DIR}/dist"
TARBALL="${CACHE_DIR}/pjproject-${PJSIP_VERSION}.tar.gz"
BCG729_TARBALL="${CACHE_DIR}/bcg729-${BCG729_VERSION}.tar.gz"
BCG729_DIR="${THIRD_PARTY}/bcg729"
BUILD_INFO="${DIST_DIR}/BUILD_INFO.txt"

FETCH_ONLY=0
FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --fetch-only) FETCH_ONLY=1 ;;
    --force) FORCE=1 ;;
    --clean) rm -rf "${PJSIP_DIR}" ;;
    *) die "unknown flag '${arg}' (supported: --fetch-only --force --clean)" ;;
  esac
done

require_tool curl "Ships with macOS"
require_tool shasum "Ships with macOS"
require_tool tar "Ships with macOS"

verify_archive() {
  # $1 = path, $2 = url, $3 = expected sha256, $4 = name
  if [[ ! -f "${1}" ]]; then
    log "Downloading ${4} from ${2}"
    curl -fsSL --retry 3 -o "${1}.tmp" "${2}" \
      || die "download failed. Check network access to github.com"
    mv "${1}.tmp" "${1}"
  fi
  local actual
  actual="$(shasum -a 256 "${1}" | awk '{print $1}')"
  if [[ "${actual}" != "${3}" ]]; then
    rm -f "${1}"
    die "SHA-256 mismatch for ${1}: expected ${3}, got ${actual}. Archive deleted; re-run to re-download. If the mismatch persists, treat it as a supply-chain red flag and STOP."
  fi
  log "Checksum OK (${4}): ${3}"
}

fetch_and_verify() {
  mkdir -p "${CACHE_DIR}"
  verify_archive "${TARBALL}" "${PJSIP_URL}" "${PJSIP_SHA256}" "pjproject ${PJSIP_VERSION}"
  verify_archive "${BCG729_TARBALL}" "${BCG729_URL}" "${BCG729_SHA256}" "bcg729 ${BCG729_VERSION}"
}

# Builds bcg729 as a static lib for one arch. Pure ANSI C — compiled
# directly with clang (no cmake dependency), laid out the way pjproject's
# --with-bcg729 expects (include/bcg729/*.h + lib/libbcg729.a).
build_bcg729_arch() {
  local arch="${1}"
  local src="${BCG729_DIR}/src-${arch}"
  local prefix="${BCG729_DIR}/dist/${arch}"
  log "=== Building bcg729 ${BCG729_VERSION} for ${arch} ==="
  rm -rf "${src}" "${prefix}"
  mkdir -p "${src}" "${prefix}/lib" "${prefix}/include"
  tar -xzf "${BCG729_TARBALL}" -C "${src}" --strip-components=1
  (
    cd "${src}"
    local objects=()
    for source_file in src/*.c; do
      local object="${source_file%.c}.o"
      clang -c -O2 -arch "${arch}" -mmacosx-version-min="${MACOS_MIN}" \
        -Iinclude -Isrc -o "${object}" "${source_file}" \
        || die "bcg729 compile failed for ${source_file} (${arch})"
      objects+=("${object}")
    done
    libtool -static -o "${prefix}/lib/libbcg729.a" "${objects[@]}" 2>/dev/null
  )
  cp -R "${src}/include/bcg729" "${prefix}/include/"
  log "${arch}: libbcg729.a ($(du -h "${prefix}/lib/libbcg729.a" | cut -f1 | tr -d ' '))"
}

write_config_site() {
  # $1 = source tree root
  cat >"${1}/pjlib/include/pj/config_site.h" <<'EOF'
/* MacSIP pinned PJSIP configuration (generated by scripts/build-pjsip.sh —
   do not hand-edit; edit the script and rebuild).
   Milestone 0 baseline: audio-only; TLS via the native Apple backend
   (Network.framework). DTLS-SRTP needs an OpenSSL-family backend and is a
   Milestone 2 decision (see docs/RESEARCH_BASELINE.md). */
#define PJ_HAS_SSL_SOCK 1
#define PJ_SSL_SOCK_IMP PJ_SSL_SOCK_IMP_APPLE
#define PJMEDIA_HAS_VIDEO 0
EOF
}

build_arch() {
  local arch="${1}"
  local src="${PJSIP_DIR}/src-${arch}"
  local prefix="${DIST_DIR}/${arch}"
  build_bcg729_arch "${arch}"
  log "=== Building pjproject ${PJSIP_VERSION} for ${arch} ==="
  rm -rf "${src}" "${prefix}"
  mkdir -p "${src}" "${prefix}"
  tar -xzf "${TARBALL}" -C "${src}" --strip-components=1
  write_config_site "${src}"
  (
    cd "${src}"
    # LIBS: the Apple TLS backend (PJ_SSL_SOCK_IMP_APPLE in config_site.h)
    # needs Network + Security at link time; configure's own "Darwin SSL"
    # autodetection is the deprecated SecureTransport backend and fails on
    # current SDKs, so we force the modern backend and its frameworks.
    ./configure \
      --host="${arch}-apple-darwin" \
      --prefix="${prefix}" \
      --with-bcg729="${BCG729_DIR}/dist/${arch}" \
      "${CONFIGURE_FLAGS[@]}" \
      CFLAGS="-arch ${arch} -mmacosx-version-min=${MACOS_MIN} -O2 -g" \
      CXXFLAGS="-arch ${arch} -mmacosx-version-min=${MACOS_MIN} -O2 -g" \
      LDFLAGS="-arch ${arch} -mmacosx-version-min=${MACOS_MIN}" \
      LIBS="-framework Network -framework Security" \
      >"${prefix}/configure.log" 2>&1 \
      || die "configure failed for ${arch}; see ${prefix}/configure.log"
    make dep >"${prefix}/make-dep.log" 2>&1 \
      || die "make dep failed for ${arch}; see ${prefix}/make-dep.log"
    make -j "$(sysctl -n hw.ncpu)" >"${prefix}/make.log" 2>&1 \
      || die "make failed for ${arch}; see ${prefix}/make.log"
    make install >"${prefix}/make-install.log" 2>&1 \
      || die "make install failed for ${arch}; see ${prefix}/make-install.log"
  )
  # Combine the per-module static libs into one archive per arch,
  # INCLUDING external codec implementations (bcg729): pjproject's install
  # only contains its own wrapper — without the implementation the app
  # link fails on _initBcg729EncoderChannel etc.
  local libs=("${prefix}/lib/"*.a "${BCG729_DIR}/dist/${arch}/lib/libbcg729.a")
  [[ -e "${libs[0]}" ]] || die "no static libraries produced for ${arch}"
  libtool -static -o "${prefix}/libpjproject-${arch}.a" "${libs[@]}" 2>/dev/null
  log "${arch}: $(basename "${prefix}/libpjproject-${arch}.a") ($(du -h "${prefix}/libpjproject-${arch}.a" | cut -f1 | tr -d ' '))"
}

merge_headers() {
  # Headers are mostly arch-neutral, but autoconf generates a few per-arch
  # files (pj/compat/m_auto.h etc.). Copy the arm64 tree, then wrap any file
  # that differs between arches in an #if defined(__aarch64__) shim.
  local a="${DIST_DIR}/arm64/include" b="${DIST_DIR}/x86_64/include"
  local out="${DIST_DIR}/universal/include"
  rm -rf "${out}"
  mkdir -p "${out}"
  cp -R "${a}/." "${out}/"
  while IFS= read -r line; do
    # diff -rq output: "Files <a>/x and <b>/x differ"
    local rel="${line#Files ${a}/}"
    rel="${rel%% and*}"
    [[ -n "${rel}" && -f "${a}/${rel}" && -f "${b}/${rel}" ]] || continue
    local dir base
    dir="$(dirname "${rel}")"
    base="$(basename "${rel}")"
    mkdir -p "${out}/${dir}"
    cp "${a}/${rel}" "${out}/${dir}/${base}.arm64"
    cp "${b}/${rel}" "${out}/${dir}/${base}.x86_64"
    cat >"${out}/${rel}" <<EOF
/* Arch-dispatch shim generated by scripts/build-pjsip.sh */
#if defined(__aarch64__)
#include "${base}.arm64"
#elif defined(__x86_64__)
#include "${base}.x86_64"
#else
#error "Unsupported architecture for MacSIP PJSIP build"
#endif
EOF
    log "header differs per arch, shimmed: ${rel}"
  done < <(diff -rq "${a}" "${b}" 2>/dev/null | grep '^Files ' || true)
}

fetch_and_verify
if [[ "${FETCH_ONLY}" -eq 1 ]]; then
  log "--fetch-only: done."
  exit 0
fi

require_tool libtool "Ships with Xcode command line tools"
require_tool lipo "Ships with Xcode command line tools"
require_tool make "Ships with Xcode command line tools"

if [[ -f "${BUILD_INFO}" && "${FORCE}" -eq 0 ]] \
  && grep -q "version=${PJSIP_VERSION}" "${BUILD_INFO}" \
  && grep -q "sha256=${PJSIP_SHA256}" "${BUILD_INFO}" \
  && [[ -f "${DIST_DIR}/universal/lib/libpjproject.a" ]]; then
  log "Up to date (${BUILD_INFO} matches pin). Use --force to rebuild."
  exit 0
fi

for arch in "${ARCHS[@]}"; do
  build_arch "${arch}"
done

mkdir -p "${DIST_DIR}/universal/lib"
lipo -create \
  "${DIST_DIR}/arm64/libpjproject-arm64.a" \
  "${DIST_DIR}/x86_64/libpjproject-x86_64.a" \
  -output "${DIST_DIR}/universal/lib/libpjproject.a"
merge_headers

{
  echo "version=${PJSIP_VERSION}"
  echo "url=${PJSIP_URL}"
  echo "sha256=${PJSIP_SHA256}"
  echo "bcg729_version=${BCG729_VERSION}"
  echo "bcg729_sha256=${BCG729_SHA256}"
  echo "macos_min=${MACOS_MIN}"
  echo "archs=${ARCHS[*]}"
  echo "configure_flags=${CONFIGURE_FLAGS[*]}"
  echo "built_with=$(xcodebuild -version | tr '\n' ' ')"
  echo "built_on=$(sw_vers -productVersion) $(uname -m)"
  echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"${BUILD_INFO}"

log "Universal library:"
lipo -info "${DIST_DIR}/universal/lib/libpjproject.a"
log "Done. Artifacts in ${DIST_DIR} (gitignored; reproducible from this script)."
