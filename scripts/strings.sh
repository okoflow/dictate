#!/bin/bash
set -euo pipefail

readonly EXTRACTED='.build/strings'
readonly LOCALIZATIONS='Packaging/Localizations'
readonly SOURCE_TABLE="${LOCALIZATIONS}/en.lproj/Localizable.strings"
readonly PLIST_KEYS='NSMicrophoneUsageDescription'
readonly USAGE='usage: scripts/strings.sh [check|update]'
readonly SPECIFIERS='def specifiers:
  [scan("%(?:[0-9]+\\$)?[-+ 0#]*[0-9]*(?:\\.[0-9]+)?(?:hh|h|ll|l|q|z|t|j|L)?[@dDiuUxXoOfeEgGcCsSpaAF%]")]
  | map(sub("^%[0-9]+\\$"; "%")) | map(select(. != "%%")) | sort;'

WORK_DIR=''

usage() {
  echo "${USAGE}" >&2

  exit 2
}

fail() {
  printf 'error: %s\n' "$@" >&2

  exit 1
}

cleanup() {
  [[ -z ${WORK_DIR} ]] || rm -rf "${WORK_DIR}"
}

code_keys() {
  local output=$1

  [[ -d ${EXTRACTED} ]] || fail "no strings in ${EXTRACTED}: run make build"

  local root sources
  root=$(pwd -P)
  sources=$(find Sources -name '*.swift')

  local file data source
  : >"${output}.unsorted"
  while IFS= read -r file; do
    data="${EXTRACTED}/$(basename "${file}" .swift).stringsdata"
    [[ -f ${data} ]] || fail "${file} has no extracted strings: run make build"

    source=$(jq -r '.source' "${data}")
    [[ ${source} == "${root}/${file}" ]] || fail "${data} belongs to ${source}: run make build"

    jq '.tables.Localizable[]?.key | select(. != "%@")' "${data}" >>"${output}.unsorted"
  done <<<"${sources}"

  LC_ALL=C sort -u "${output}.unsorted" >"${output}"
}

table_keys() {
  local table=$1 output=$2

  plutil -convert json -o "${output}.json" "${table}"
  jq 'keys[]' "${output}.json" >"${output}.unsorted"
  LC_ALL=C sort -u "${output}.unsorted" >"${output}"
}

check_keys() {
  local table=$1 expected=$2 hint=$3
  local actual="${WORK_DIR}/actual"

  plutil -lint -s "${table}" || fail "${table} isn't a valid strings file"
  table_keys "${table}" "${actual}"

  local missing extra
  missing=$(LC_ALL=C comm -23 "${expected}" "${actual}")
  extra=$(LC_ALL=C comm -13 "${expected}" "${actual}")

  [[ -z ${missing} ]] || fail "${table} is missing keys${hint}:" "${missing}"
  [[ -z ${extra} ]] || fail "${table} has keys the code no longer uses${hint}:" "${extra}"
}

check_specifiers() {
  local table=$1
  local json="${WORK_DIR}/table.json"

  plutil -convert json -o "${json}" "${table}"

  local mismatched
  mismatched=$(jq -r "${SPECIFIERS} to_entries[] | select((.key | specifiers) != (.value | specifiers)) | .key" "${json}")

  [[ -z ${mismatched} ]] || fail "${table} changes the placeholders of:" "${mismatched}"
}

check_plist_strings() {
  local table="$1/InfoPlist.strings"

  [[ -f ${table} ]] || fail "${table} is missing"
  plutil -lint -s "${table}" || fail "${table} isn't a valid strings file"

  local key
  for key in ${PLIST_KEYS}; do
    plutil -extract "${key}" raw -o /dev/null "${table}" || fail "${table} has no ${key}"
  done
}

check() {
  local expected="${WORK_DIR}/expected"
  local languages=0

  code_keys "${expected}"
  check_keys "${SOURCE_TABLE}" "${expected}" ' (run make strings-update)'

  local directory
  for directory in "${LOCALIZATIONS}"/*.lproj; do
    languages=$((languages + 1))
    [[ ${directory} == "$(dirname "${SOURCE_TABLE}")" ]] && continue

    check_keys "${directory}/Localizable.strings" "${expected}" ''
    check_specifiers "${directory}/Localizable.strings"
    check_plist_strings "${directory}"
  done

  local count
  count=$(wc -l <"${expected}")

  echo "strings: ${count// /} keys in ${languages} languages"
}

update() {
  local keys="${WORK_DIR}/keys"

  code_keys "${keys}"
  mkdir -p "$(dirname "${SOURCE_TABLE}")"

  local key
  while IFS= read -r key; do
    printf '%s = %s;\n' "${key}" "${key}"
  done <"${keys}" >"${SOURCE_TABLE}"

  echo "${SOURCE_TABLE}"
}

main() {
  [[ $# -le 1 ]] || usage

  cd "$(dirname "$0")/.."

  WORK_DIR=$(mktemp -d)
  trap cleanup EXIT

  case ${1:-check} in
    check) check ;;
    update) update ;;
    *) usage ;;
  esac
}

main "$@"
