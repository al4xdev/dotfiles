#!/usr/bin/env bash
# Empacota a entrega: os .mp4 finais (sem .raw), o INDEX.md e as legendas .ass.
#
#   bash package-zip.sh [nome=tutoriais]   # gera $OUT_DIR/../<nome>.zip
set -eu
OUT_DIR="${OUT_DIR:-out}"
name="${1:-tutoriais}"
stage="$(mktemp -d)/$name"
mkdir -p "$stage"
for f in "$OUT_DIR"/*.mp4; do
  case "$f" in *.raw.mp4) continue ;; esac
  cp "$f" "$stage/"
  base="${f%.mp4}"
  [ -f "$base.ass" ] && cp "$base.ass" "$stage/"
done
[ -f "$OUT_DIR/INDEX.md" ] && cp "$OUT_DIR/INDEX.md" "$stage/"
zip_path="$(cd "$OUT_DIR/.." && pwd)/$name.zip"
rm -f "$zip_path"
(cd "$(dirname "$stage")" && zip -qr "$zip_path" "$name")
echo "ok: $zip_path"
unzip -l "$zip_path" | tail -n +1