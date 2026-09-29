#!/usr/bin/env bash
# Fails if line coverage of Sources/DictateCore is below the threshold (default 70%).
# Run after `swift test --enable-code-coverage`.
set -euo pipefail
cd "$(dirname "$0")/.."

threshold=${COVERAGE_THRESHOLD:-70}
bin_dir=$(swift build --show-bin-path)
profdata=$(find "$bin_dir/codecov" -name default.profdata | head -1)
test_bundle=$(find "$bin_dir" -maxdepth 1 -name '*.xctest' | head -1)

if [[ -z "$profdata" || -z "$test_bundle" ]]; then
    echo "no coverage data: run 'swift test --enable-code-coverage' first" >&2
    exit 1
fi

binary="$test_bundle/Contents/MacOS/$(basename "$test_bundle" .xctest)"
percent=$(xcrun llvm-cov export -summary-only -instr-profile "$profdata" "$binary" |
    jq -r '[.data[0].files[] | select(.filename | contains("/Sources/DictateCore/"))]
           | (map(.summary.lines.covered) | add) / (map(.summary.lines.count) | add) * 100')

printf 'DictateCore line coverage: %.1f%% (threshold %s%%)\n' "$percent" "$threshold"
awk -v value="$percent" -v limit="$threshold" 'BEGIN { exit !(value >= limit) }'
