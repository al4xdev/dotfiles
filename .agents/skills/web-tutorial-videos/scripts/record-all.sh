#!/usr/bin/env bash
# Grava + monta fluxos em sequência (nunca dois ao mesmo tempo: compartilhariam o backend).
#
#   bash record-all.sh                 # todos os flows/*.mjs, em ordem alfabética
#   bash record-all.sh fluxo-a fluxo-b # só estes, nesta ordem (dependências primeiro)
#
# Ambiente: FLOWS_DIR (flows), OUT_DIR (out), QUIET_REPO + QUIET_MINUTES (ver check-quiet.sh;
# se QUIET_REPO estiver definido, aborta quando o repositório não está quieto; FORCE=1 ignora).
# Logs em $OUT_DIR/logs/<fluxo>.rec.log e .mont.log.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FLOWS_DIR="${FLOWS_DIR:-flows}"
export OUT_DIR="${OUT_DIR:-out}"
mkdir -p "$OUT_DIR/logs"

if [ -n "${QUIET_REPO:-}" ] && [ "${FORCE:-0}" != 1 ]; then
  bash "$HERE/check-quiet.sh" "$QUIET_REPO" || { echo "repositório não está quieto; FORCE=1 para gravar assim mesmo"; exit 3; }
fi

FLOWS=("$@")
if [ ${#FLOWS[@]} -eq 0 ]; then
  for f in "$FLOWS_DIR"/*.mjs; do FLOWS+=("$(basename "$f" .mjs)"); done
fi

fail=0
for f in "${FLOWS[@]}"; do
  echo "=== $f $(date +%T)"
  if node "$HERE/recorder.mjs" "$FLOWS_DIR/$f.mjs" > "$OUT_DIR/logs/$f.rec.log" 2>&1; then
    if uv run -q --with numpy python "$HERE/montage.py" "$f" --out-dir "$OUT_DIR" > "$OUT_DIR/logs/$f.mont.log" 2>&1; then
      echo "ok $f"
    else
      echo "MONTAGE FAIL $f"; tail -5 "$OUT_DIR/logs/$f.mont.log"; fail=1
    fi
  else
    echo "REC FAIL $f"; tail -5 "$OUT_DIR/logs/$f.rec.log"; fail=1
  fi
done

if [ -n "${QUIET_REPO:-}" ]; then
  echo "depois: $(git -C "$QUIET_REPO" log -1 --format='%h %cr') dirty=$(git -C "$QUIET_REPO" status --short | wc -l)"
fi
exit $fail