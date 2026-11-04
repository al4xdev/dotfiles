#!/usr/bin/env bash
# O front está "quieto" para a gravação final? Árvore limpa E último commit há mais de N min.
#
#   bash check-quiet.sh <repo-do-front> [minutos=${QUIET_MINUTES:-10}]
#
# Sai 0 quando quieto; 1 com o motivo. Gravar com alguém editando = Vite recarregando no meio
# do passo e texto de tela que muda depois da legenda escrita.
set -u
repo="${1:?uso: check-quiet.sh <repo> [minutos]}"
min="${2:-${QUIET_MINUTES:-10}}"
dirty=$(git -C "$repo" status --short | wc -l)
last=$(git -C "$repo" log -1 --format=%ct)
age=$(( ($(date +%s) - last) / 60 ))
echo "repo=$repo head=$(git -C "$repo" log -1 --format=%h) último commit há ${age} min, dirty=$dirty"
[ "$dirty" -eq 0 ] || { echo "não quieto: árvore com mudanças"; exit 1; }
[ "$age" -ge "$min" ] || { echo "não quieto: espere mais $((min - age)) min"; exit 1; }
echo quieto