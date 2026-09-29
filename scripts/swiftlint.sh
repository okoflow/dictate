#!/usr/bin/env bash
# Runs SwiftLint in strict mode. With only Command Line Tools installed, SwiftLint cannot find
# sourcekitd on its own, so point it there. Usage: scripts/swiftlint.sh [files...]
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(xcode-select -p 2> /dev/null)" == *CommandLineTools* ]]; then
    export TOOLCHAIN_DIR=/Library/Developer/CommandLineTools
fi
exec swiftlint lint --strict --quiet "$@"
