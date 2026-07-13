#!/usr/bin/env bash
# generate-certs.sh — throwaway self-signed CA + server cert for the
# TestPBX TLS transport. TEST-ONLY material: keys/ is gitignored and must
# never be reused outside the local TestPBX.
#
# The server cert carries SAN IP:127.0.0.1 (Apple's TLS stack requires
# SANs; CN alone is ignored). MacSIP's cert-validation tests rely on this
# CA being UNTRUSTED by the system: verification must fail until the
# per-account insecure override (or explicit CA install) is used.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS="${SCRIPT_DIR}/asterisk/keys"

command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl not found" >&2; exit 1; }

if [[ -f "${KEYS}/asterisk.crt" && "${1:-}" != "--force" ]]; then
  echo "[generate-certs] certs exist (${KEYS}); use --force to regenerate"
  exit 0
fi

mkdir -p "${KEYS}"
cd "${KEYS}"

openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.crt -days 365 -nodes \
  -subj "/CN=MacSIP TestPBX CA (throwaway)" 2>/dev/null

openssl req -newkey rsa:2048 -keyout asterisk.key -out asterisk.csr -nodes \
  -subj "/CN=127.0.0.1" 2>/dev/null

printf "subjectAltName=IP:127.0.0.1,DNS:localhost\nextendedKeyUsage=serverAuth\n" > san.ext
openssl x509 -req -in asterisk.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out asterisk.crt -days 365 -extfile san.ext 2>/dev/null
rm -f asterisk.csr san.ext ca.srl

chmod 644 ca.crt asterisk.crt
chmod 600 ca.key asterisk.key
echo "[generate-certs] wrote CA + server cert to ${KEYS} (gitignored, throwaway)"
