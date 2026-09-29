#!/usr/bin/env bash
# Builds a product and wraps it into build/<Product>.app, then code-signs it.
# Usage: scripts/bundle.sh <Product> [debug|release]
#
# Signing matters: macOS ties privacy permissions (microphone, Accessibility, Input Monitoring)
# to the app's code signature. An ad-hoc signature changes on every build, so permissions
# would reset each time. Run scripts/setup-signing.sh once to get a stable identity.
set -euo pipefail
cd "$(dirname "$0")/.."

product=${1:?usage: bundle.sh <Product> [debug|release]}
config=${2:-debug}
identity=${DICTATE_SIGN_IDENTITY:-Dictate Dev}
keychain=${DICTATE_KEYCHAIN:-}

swift build -c "$config" --product "$product" >&2
bin_dir=$(swift build -c "$config" --show-bin-path)

app="build/$product.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/$product" "$app/Contents/MacOS/$product"
cp "Packaging/$product-Info.plist" "$app/Contents/Info.plist"

find_args=(-p codesigning)
sign_args=(--force)
if [[ -n "$keychain" ]]; then
    find_args+=("$keychain")
    sign_args+=(--keychain "$keychain")
fi

if security find-identity -v "${find_args[@]}" | grep -q "\"$identity\""; then
    codesign "${sign_args[@]}" --sign "$identity" "$app"
    echo "signed $app with \"$identity\"" >&2
else
    codesign --force --sign - "$app"
    echo "WARNING: identity \"$identity\" not found; signed $app ad-hoc." >&2
    echo "         Permissions will reset on every rebuild. Run scripts/setup-signing.sh" >&2
fi
echo "$app"
