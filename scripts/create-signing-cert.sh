#!/usr/bin/env bash
#
# Create a stable, self-signed **code-signing** identity for local xtty builds.
#
# Why: xtty is ad-hoc signed ("Sign to Run Locally"), so its code identity (cdhash)
# changes on every rebuild and macOS re-prompts for Screen Recording (the latency
# probe's TCC grant) each time. Signing with a STABLE self-signed cert keeps the
# identity constant across rebuilds, so the grant persists and the prompts stop.
#
# This is purely a LOCAL dev convenience: nothing here is committed signing config,
# and the default build stays ad-hoc + portable. After running this once:
#
#     export XTTY_SIGN_IDENTITY=xtty-dev
#     make bench        # grant Screen Recording ONCE; it persists across rebuilds
#
# Undo:  security delete-identity -c xtty-dev   (removes the cert from your keychain)
#
# Run it from your interactive terminal (it may prompt for your login/keychain
# password, and the first signed build shows a one-time "codesign wants to use key"
# dialog — click **Always Allow**).
set -euo pipefail

CERT_NAME="${1:-xtty-dev}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
  echo "Code-signing identity '$CERT_NAME' already exists. Use it with:"
  echo "    export XTTY_SIGN_IDENTITY=$CERT_NAME"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# OpenSSL config (config-file form works on both LibreSSL — macOS default — and
# OpenSSL, unlike `-addext`). codeSigning EKU is what `codesign` requires.
cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[dn]
CN = $CERT_NAME
[v3]
basicConstraints   = critical,CA:false
keyUsage           = critical,digitalSignature
extendedKeyUsage   = critical,codeSigning
EOF

echo "Generating a self-signed code-signing certificate '$CERT_NAME'…"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf"

# Import the key + cert as one combined PEM. (A PKCS#12 round-trip is fragile on
# macOS: the system Security framework can't verify the MAC of a p12 produced by
# LibreSSL / OpenSSL 3 — "MAC verification failed" — so we skip p12 entirely.)
cat "$TMP/key.pem" "$TMP/cert.pem" > "$TMP/identity.pem"

echo "Importing into your login keychain (authorizing codesign to use the key)…"
security import "$TMP/identity.pem" -k "$KEYCHAIN" -T /usr/bin/codesign

# Let codesign use the key without a GUI prompt on every build. Needs the login
# keychain password; if it can't run non-interactively, codesign will instead show
# a one-time "Always Allow" dialog on the first signed build (also fine).
echo "Allowing codesign non-interactive key access (may prompt for your keychain password)…"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s "$KEYCHAIN" >/dev/null 2>&1 \
  || echo "  (skipped — the first signed build will show a 'codesign wants to use key' dialog; click Always Allow)"

echo
echo "✅ Created code-signing identity '$CERT_NAME'. Next:"
echo "    export XTTY_SIGN_IDENTITY=$CERT_NAME"
echo "    make bench     # grant Screen Recording once; it now persists across rebuilds"
