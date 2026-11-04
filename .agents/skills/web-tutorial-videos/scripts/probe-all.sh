#!/usr/bin/env bash
# ffprobe dos vídeos finais (pula *.raw.mp4) e 4 quadros de cada em $OUT_DIR/frames/
# (12%, 38%, 62%, 88% da duração) para conferir com um visualizador de imagem.
#
#   bash probe-all.sh            # OUT_DIR=out
#   FRACS="0.2 0.5 0.8" bash probe-all.sh
set -u
OUT_DIR="${OUT_DIR:-out}"
FRACS="${FRACS:-0.12 0.38 0.62 0.88}"
mkdir -p "$OUT_DIR/frames"
for f in "$OUT_DIR"/*.mp4; do
  case "$f" in *.raw.mp4) continue ;; esac
  [ -e "$f" ] || continue
  name=$(basename "$f" .mp4)
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  streams=$(ffprobe -v error -show_entries stream=codec_name,width,height -of csv=p=0 "$f" | tr '\n' ' ')
  size=$(stat -c %s "$f")
  printf '%s dur=%.1fs size=%dKB streams=%s\n' "$name" "$dur" $((size / 1024)) "$streams"
  for frac in $FRACS; do
    t=$(awk -v d="$dur" -v p="$frac" 'BEGIN{printf "%.2f", d*p}')
    ffmpeg -v error -y -ss "$t" -i "$f" -frames:v 1 -vf scale=960:-1 "$OUT_DIR/frames/$name-$frac.jpg"
  done
done