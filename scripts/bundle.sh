#!/bin/bash
set -euo pipefail

readonly PRODUCT='Dictate'
readonly APP="build/${PRODUCT}.app"
readonly IDENTITY='Dictate Dev'
readonly USAGE='usage: scripts/bundle.sh [debug|release]'

usage() {
  echo "${USAGE}" >&2

  exit 2
}

build_binary() {
  local configuration=$1

  swift build --configuration "${configuration}" --product "${PRODUCT}" >&2

  swift build --configuration "${configuration}" --show-bin-path
}

assemble_app() {
  local binary_dir=$1

  rm -rf "${APP}"
  mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

  cp "${binary_dir}/${PRODUCT}" "${APP}/Contents/MacOS/${PRODUCT}"
  cp "Packaging/${PRODUCT}-Info.plist" "${APP}/Contents/Info.plist"
  cp "Packaging/${PRODUCT}.icns" "${APP}/Contents/Resources/${PRODUCT}.icns"
}

has_identity() {
  security find-identity -v -p codesigning | grep -q "\"${IDENTITY}\""
}

sign_app() {
  if has_identity; then
    codesign --force --sign "${IDENTITY}" "${APP}"

    echo "signed ${APP} with \"${IDENTITY}\"" >&2

    return
  fi

  codesign --force --sign - "${APP}"

  echo "warning: ${APP} is signed ad hoc, so rebuilds lose its permissions" >&2
  echo "warning: run make signing once to keep them" >&2
}

main() {
  [[ $# -le 1 ]] || usage

  local configuration=${1:-debug}
  [[ ${configuration} == debug || ${configuration} == release ]] || usage

  cd "$(dirname "$0")/.."

  local binary_dir
  binary_dir=$(build_binary "${configuration}")

  assemble_app "${binary_dir}"
  sign_app

  echo "${APP}"
}

main "$@"
