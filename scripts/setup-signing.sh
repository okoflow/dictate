#!/bin/bash
set -euo pipefail

readonly NAME='Waft Dev'
readonly KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
readonly EXPORT_PASSWORD='waft'

die() {
  echo "error: $*" >&2

  exit 1
}

has_identity() {
  security find-identity "$@" -p codesigning "${KEYCHAIN}" \
    | grep -q "\"${NAME}\""
}

write_certificate_config() {
  local path=$1

  cat >"${path}" <<CONFIG
[req]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[dn]
CN = ${NAME}

[ext]
basicConstraints = critical,CA:false
keyUsage         = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIG
}

create_identity() {
  write_certificate_config "${WORK_DIR}/openssl.cnf"

  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "${WORK_DIR}/openssl.cnf" \
    -keyout "${WORK_DIR}/key.pem" \
    -out "${WORK_DIR}/certificate.pem" 2>/dev/null

  /usr/bin/openssl pkcs12 -export \
    -inkey "${WORK_DIR}/key.pem" \
    -in "${WORK_DIR}/certificate.pem" \
    -name "${NAME}" \
    -out "${WORK_DIR}/identity.p12" \
    -passout "pass:${EXPORT_PASSWORD}"

  security import "${WORK_DIR}/identity.p12" \
    -k "${KEYCHAIN}" \
    -P "${EXPORT_PASSWORD}" \
    -T /usr/bin/codesign >/dev/null

  echo "created \"${NAME}\" in ${KEYCHAIN}"
}

trust_identity() {
  security find-certificate -c "${NAME}" -p "${KEYCHAIN}" \
    >"${WORK_DIR}/trust.pem"

  security add-trusted-cert -r trustRoot -p codeSign "${WORK_DIR}/trust.pem"
}

main() {
  if has_identity -v; then
    echo "\"${NAME}\" is already installed and trusted"

    return
  fi

  WORK_DIR=$(mktemp -d)
  readonly WORK_DIR
  trap 'rm -rf "${WORK_DIR}"' EXIT

  if ! has_identity; then
    create_identity
  fi

  trust_identity

  has_identity -v || die "\"${NAME}\" is not trusted; run make signing again"

  echo "\"${NAME}\" is ready"
}

main "$@"
