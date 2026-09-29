#!/usr/bin/env bash
# Downloads real human speech with exact transcripts for ru / en / ko from Google FLEURS
# (https://huggingface.co/datasets/google/fleurs, CC-BY 4.0) into fixtures/private/.
#
# Output per clip: <lang>-<n>.wav (16 kHz mono, 16-bit) and <lang>-<n>.txt (exact transcript),
# plus fixtures/private/SOURCES.md with attribution. The folder is git-ignored.
# Picks short clips (4–12 s) without Latin letters in ru/ko, alternating speaker gender.
# Usage: scripts/fetch-fleurs.sh [clips_per_language]
set -euo pipefail
cd "$(dirname "$0")/.."

per_language=${1:-5}
out=fixtures/private
api="https://datasets-server.huggingface.co/rows?dataset=google/fleurs&split=validation"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

{
    echo "# Speech fixture sources"
    echo
    echo "Clips from Google FLEURS (validation split), https://huggingface.co/datasets/google/fleurs"
    echo "License: CC-BY 4.0. Conneau et al., \"FLEURS: Few-shot Learning Evaluation of Universal"
    echo "Representations of Speech\", 2022."
    echo
    echo "| File | FLEURS config | Row id | Gender | Seconds |"
    echo "|---|---|---|---|---|"
} > "$out/SOURCES.md"

select_rows() {
    local lang=$1
    # Short clips; for ru/ko skip transcripts with Latin letters (mixed-script names skew CER).
    # Sort so genders alternate: 0 (male) and 1 (female) interleaved.
    jq -c --arg lang "$lang" --argjson limit "$per_language" '
        [.rows[].row
         | select(.num_samples >= 64000 and .num_samples <= 192000)
         | select($lang == "en" or (.raw_transcription | test("[A-Za-z]") | not))]
        | group_by(.gender)
        | [range(0; (map(length) | max)) as $i | .[] | .[$i] // empty]
        | .[:$limit][]
        | {id, gender, seconds: (.num_samples / 16000 * 10 | round / 10),
           text: .raw_transcription, url: .audio[0].src}'
}

for pair in ru:ru_ru en:en_us ko:ko_kr; do
    lang=${pair%%:*}
    config=${pair#*:}
    curl -fsS "$api&config=$config&offset=0&length=100" > "$work/$lang.json"

    n=0
    while IFS= read -r row; do
        n=$((n + 1))
        name="$lang-$n"
        curl -fsS -o "$work/$name.wav" "$(jq -r .url <<< "$row")"
        afconvert -f WAVE -d LEI16@16000 -c 1 "$work/$name.wav" "$out/$name.wav"
        jq -r .text <<< "$row" > "$out/$name.txt"
        gender=$(jq -r 'if .gender == 0 then "male" elif .gender == 1 then "female" else "other" end' <<< "$row")
        echo "| $name.wav | $config | $(jq -r .id <<< "$row") | $gender | $(jq -r .seconds <<< "$row") |" \
            >> "$out/SOURCES.md"
        echo "fetched $out/$name.wav"
    done < <(select_rows "$lang" < "$work/$lang.json")

    if [[ $n -lt $per_language ]]; then
        echo "only $n suitable $lang clips found (wanted $per_language)" >&2
        exit 1
    fi
done
