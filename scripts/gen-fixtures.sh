#!/usr/bin/env bash
# Generates speech fixtures from fixtures/manifest.json with macOS `say`.
# Output: fixtures/generated/<id>.wav (16 kHz mono, 16-bit). Existing files are kept.
# Voices needed: Milena (ru), Samantha (en), Yuna (ko) — System Settings → Accessibility →
# Spoken Content → System Voice → Manage Voices.
set -euo pipefail
cd "$(dirname "$0")/.."

manifest=fixtures/manifest.json
out=fixtures/generated
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

missing=0
while IFS= read -r voice; do
    if ! say -v '?' | grep -q "^$voice "; then
        echo "missing voice: $voice" >&2
        missing=1
    fi
done < <(jq -r '.[].voice' "$manifest" | sort -u)
if [[ $missing -eq 1 ]]; then
    echo "install the voices listed above and re-run" >&2
    exit 1
fi

while IFS=$'\t' read -r id voice text tags; do
    target="$out/$id.wav"
    [[ -f "$target" ]] && continue

    if [[ ",$tags," == *",noisy,"* ]]; then
        base="$out/${id%-noisy}.wav"
        [[ -f "$base" ]] || { echo "noisy fixture $id needs $base first" >&2; exit 1; }
        python3 scripts/add_noise.py "$base" "$target" 15
    else
        say -v "$voice" -o "$work/$id.aiff" -- "$text"
        afconvert -f WAVE -d LEI16@16000 -c 1 "$work/$id.aiff" "$target"
    fi
    echo "generated $target"
done < <(jq -r '(map(select((.tags | index("noisy")) | not)) + map(select(.tags | index("noisy")))) | .[] | [.id, .voice, .text, (.tags | join(","))] | @tsv' "$manifest")
