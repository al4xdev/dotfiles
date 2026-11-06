#!/usr/bin/env bash
# Offline post-processing of a Video Intelligence operation.json (bash + jq + ffmpeg only).
#   vi-outputs.sh outputs OPERATION_JSON OUTDIR  -> transcript.md, transcript-speakers.md, shots.json, ocr.json, frames-plan.json
#   vi-outputs.sh frames  VIDEO_MP4 OUTDIR       -> frames/f-<mmss>.jpg + frames/index.md (needs the files above)
# Env: MIN_SHOT=1.5 (s), MAX_FRAMES=60
set -euo pipefail

# Durations arrive as "12.500s"; the field is omitted when it is 0.
DEFS='
def sec: (. // "0s") | rtrimstr("s") | tonumber;
def p2: tostring | if length < 2 then "0" + . else . end;
def mmss: floor as $s | "\(($s / 60 | floor) | p2):\(($s % 60) | p2)";
def fname: floor as $s | "f-\(($s / 60 | floor) | p2)\(($s % 60) | p2).jpg";
'
MIN_SHOT="${MIN_SHOT:-1.5}"
MAX_FRAMES="${MAX_FRAMES:-60}"

outputs() {
  local op="$1" out="$2"
  mkdir -p "$out"
  [ "$(jq -r '.done // false' "$op")" = true ] || { echo "operation not done" >&2; exit 1; }
  [ "$(jq -r '.error // empty' "$op")" = "" ] || { jq '.error' "$op" >&2; exit 1; }

  # One line per alternative, with the time of its first word.
  # With diarization the API appends one extra transcription holding ALL words with speakerTag;
  # drop it here (it is used for the speaker version below).
  jq -r "$DEFS"'
    [.response.annotationResults[] | (.speechTranscriptions // [])
     | if length > 1 and (.[-1].alternatives[0].words[-1].speakerTag // 0) != 0 then .[:-1] else . end
     | .[].alternatives[0]?
     | select(. != null and .transcript != null and (.words | length > 0))]
    | .[] | "[\(.words[0].startTime | sec | mmss)] \(.transcript | ltrimstr(" "))"' \
    "$op" > "$out/transcript.md"

  # Speaker turns: consecutive words with the same speakerTag (only the last result carries tags).
  jq -r "$DEFS"'
    [.response.annotationResults[].speechTranscriptions[]?.alternatives[0]?.words[]? | select(.speakerTag != null)]
    | reduce .[] as $x ([];
        if length > 0 and .[-1].tag == $x.speakerTag then .[-1].words += [$x.word]
        else . + [{tag: $x.speakerTag, start: ($x.startTime | sec), words: [$x.word]}] end)
    | .[] | "[\(.start | mmss)] Speaker \(.tag): \(.words | join(" "))"' \
    "$op" > "$out/transcript-speakers.md"

  jq "$DEFS"'
    [.response.annotationResults[].shotAnnotations[]?
     | {start: (.startTimeOffset | sec), end: (.endTimeOffset | sec)}]' \
    "$op" > "$out/shots.json"

  jq "$DEFS"'
    [.response.annotationResults[].textAnnotations[]? | select(.segments | length > 0)
     | {text, start: (.segments[0].segment.startTimeOffset | sec), end: (.segments[0].segment.endTimeOffset | sec)}]
    | sort_by(.start)' \
    "$op" > "$out/ocr.json"

  # Plan: midpoints of shots >= MIN_SHOT (keep the longest MAX_FRAMES) + OCR bursts (>= 4 new
  # texts within the same 2 s window = screen changed); drop plan entries closer than 3 s.
  jq -n "$DEFS"'
    ($s[0] | map(select(.end - .start >= $min)) | sort_by(-(.end - .start)) | .[:$max] | sort_by(.start)
      | map({t: ((.start + .end) / 2), why: "shot"})) as $shots
    | ($o[0] | group_by(.start / 2 | floor) | map(select(length >= 4) | {t: (.[0].start + 1), why: "ocr-change"})) as $ocr
    | reduce ($shots + $ocr | sort_by(.t))[] as $f ([];
        if length > 0 and ($f.t - .[-1].t) < 3 then . else . + [$f] end)' \
    --argjson min "$MIN_SHOT" --argjson max "$MAX_FRAMES" \
    --slurpfile s "$out/shots.json" --slurpfile o "$out/ocr.json" \
    > "$out/frames-plan.json"
  echo "ok: $(jq length "$out/frames-plan.json") frames planned, $(wc -l < "$out/transcript.md") transcript lines"
}

frames() {
  local video="$1" out="$2"
  mkdir -p "$out/frames"
  jq -r "$DEFS"'.[] | "\(.t) \(.t | fname)"' "$out/frames-plan.json" |
    while read -r t f; do
      # API offsets can come out as ".35" (no leading 0), which ffmpeg rejects; -nostdin keeps
      # ffmpeg from eating the rest of this while-read loop's input.
      t=$(printf '%.3f' "$t")
      ffmpeg -nostdin -v error -y -ss "$t" -i "$video" -frames:v 1 -vf scale=1280:-1 "$out/frames/$f"
    done
  # Transcript lines as {t, line}, so the index can say what is being said at T.
  jq -R -s "$DEFS"'
    split("\n") | map(select(length > 0)
      | capture("^\\[(?<m>[0-9]+):(?<s>[0-9]+)\\] (?<line>.*)$")
      | {t: ((.m | tonumber) * 60 + (.s | tonumber)), line})' \
    "$out/transcript.md" > "$out/.tr.json"
  jq -r "$DEFS"'
    "# Frame index\n\n| time | file | OCR near it | transcript at that time |\n|---|---|---|---|",
    (.[] | .t as $t
      | (($o[0] | map(select(.start <= $t and .end >= $t) | .text) | unique | .[:8] | join(" / ")) | gsub("[|\n]"; " ")) as $ocr
      | (($tr[0] | map(select(.t <= $t)) | last // {line: ""} | .line) | gsub("[|\n]"; " ")) as $line
      | "| \($t | mmss) | frames/\($t | fname) | \($ocr) | \($line) |")' \
    --slurpfile o "$out/ocr.json" --slurpfile tr "$out/.tr.json" \
    "$out/frames-plan.json" > "$out/frames/index.md"
  rm -f "$out/.tr.json"
  echo "ok: $(find "$out/frames" -name '*.jpg' | wc -l) frames in $out/frames"
}

case "${1:-}" in
  outputs) [ $# -eq 3 ] || { echo "usage: $0 outputs OPERATION_JSON OUTDIR" >&2; exit 2; }; outputs "$2" "$3" ;;
  frames)  [ $# -eq 3 ] || { echo "usage: $0 frames VIDEO_MP4 OUTDIR" >&2; exit 2; }; frames "$2" "$3" ;;
  *) echo "usage: $0 {outputs|frames} ..." >&2; exit 2 ;;
esac
