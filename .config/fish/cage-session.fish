#!/usr/bin/fish
# Executado como cliente do Cage: só aqui WAYLAND_DISPLAY aponta para a nova sessão.
set -l output DP-1
set -l mode 2560x1440@164.956Hz

set -l state (command wlr-randr --json)
if test $status -ne 0
    printf '%s\n' 'Não foi possível consultar as saídas do Cage. Voltando ao TTY.' >&2
    exit 1
end
set -l outputs (printf '%s\n' $state | command jq -er '.[].name')
if test $status -ne 0; or not contains -- "$output" $outputs
    printf 'Saída %s indisponível. Confira o cabo DisplayPort. Voltando ao TTY.\n' "$output" >&2
    exit 1
end

# Aplica uma configuração única: não desliga o HDMI antes de validar o DisplayPort.
# Só inclui saídas anunciadas pelo Cage; HDMI desconectado não causa erro.
set -l output_args --output "$output" --on --mode "$mode" --pos 0,0
for other in $outputs
    if test "$other" != "$output"
        set -a output_args --output "$other" --off
    end
end

if not command wlr-randr --dryrun $output_args
    printf 'O Cage rejeitou %s em %s. Voltando ao TTY.\n' "$mode" "$output" >&2
    exit 1
end
if not command wlr-randr $output_args
    printf 'Falha ao aplicar %s em %s. Voltando ao TTY.\n' "$mode" "$output" >&2
    exit 1
end

# Isola os atalhos Super do Cage, sem sobrescrever o perfil padrão do COSMIC.
# O terminal inicial começa na home, independentemente do diretório herdado do Cage.
exec kitty --config "$HOME/.config/kitty/kitty-cage.conf" --directory "$HOME" -o linux_display_server=wayland
