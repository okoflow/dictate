#!/usr/bin/env bash
# Creates a self-signed code-signing identity ("Dictate Dev" by default) and marks it trusted
# for code signing, so macOS keeps the privacy permissions you grant to Dictate across rebuilds.
# Safe to run repeatedly.
#
# What it changes on your Mac:
#   * adds one certificate + private key to your login keychain;
#   * adds a user-level trust setting for that certificate (code signing only).
# macOS will ask for your password / Touch ID for the trust step, and the first `codesign` run
# may ask whether codesign can use the key: choose "Always Allow".
set -euo pipefail

name=${DICTATE_SIGN_IDENTITY:-Dictate Dev}
keychain=${DICTATE_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}
p12_password=dictate

has_identity() { security find-identity "$@" -p codesigning "$keychain" | grep -q "\"$name\""; }

if has_identity -v; then
    echo "identity \"$name\" is already installed and trusted"
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! has_identity; then
    cat > "$work/openssl.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF

    # /usr/bin/openssl (LibreSSL) writes a PKCS#12 that `security import` understands;
    # Homebrew's OpenSSL 3 does not.
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -config "$work/openssl.cnf" -keyout "$work/key.pem" -out "$work/cert.pem" 2> /dev/null
    /usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
        -name "$name" -out "$work/identity.p12" -passout "pass:$p12_password"
    security import "$work/identity.p12" -k "$keychain" -P "$p12_password" -T /usr/bin/codesign > /dev/null
    echo "created identity \"$name\" in $keychain"
fi

# codesign only accepts identities whose certificate is trusted for code signing.
security find-certificate -c "$name" -p "$keychain" > "$work/trust.pem"
security add-trusted-cert -r trustRoot -p codeSign "$work/trust.pem"

if has_identity -v; then
    echo "identity \"$name\" is ready"
else
    echo "identity \"$name\" exists but is not trusted yet; run this script again" >&2
    exit 1
fi
