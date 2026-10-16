function start_graphic --description 'Seleciona console puro, Cage + Kitty ou COSMIC direto do TTY'
    argparse --name=start_graphic --exclusive=tty,cage,cosmic h/help tty cage cosmic -- $argv
    or return 2
    if test (count $argv) -gt 0
        printf '%s\n' 'Use: start_graphic --tty | --cage | --cosmic' >&2
        return 2
    end

    set -l mode ''
    if set -q _flag_tty
        set mode tty
    else if set -q _flag_cage
        set mode cage
    else if set -q _flag_cosmic
        set mode cosmic
    end
    if set -q _flag_help; or test -z "$mode"
        printf '%s\n' 'Uso: start_graphic [--tty | --cage | --cosmic]' \
            '  --tty     Para o SDDM, se ativo, e permanece no console.' \
            '  --cage    Abre Kitty no Cage: DP-1 a 165 Hz, teclado US International AltGr.' \
            '  --cosmic  Abre COSMIC diretamente no TTY; ao sair, retorna ao console.' \
            'Execute os modos em um TTY local, fora do Cage/desktop e do SSH.' \
            'Nenhum modo altera quais serviços iniciam no boot.'
        return 0
    end

    set -l terminal (command tty 2>/dev/null)
    # Parar o desktop de dentro dele mataria o shell antes de concluir a troca.
    if not string match --quiet --regex '^/dev/tty[0-9]+$' -- "$terminal"; or set -q SSH_CONNECTION; or set -q SSH_TTY
        printf '%s\n' 'Use um TTY local: Ctrl+Alt+F3, faça login e execute novamente.' \
            'Se estiver no Cage, salve seu trabalho e feche seus painéis antes de trocar de modo.' >&2
        return 1
    end

    # Não disputa a GPU com um Cage deixado aberto em outro console.
    command pgrep --uid (id -u) --exact cage >/dev/null
    set -l cage_check $status
    if test $cage_check -eq 0
        printf '%s\n' 'Há um Cage aberto neste usuário. Saia dele antes de trocar de modo.' >&2
        return 1
    else if test $cage_check -ne 1
        printf '%s\n' 'Não foi possível verificar se já existe um Cage aberto.' >&2
        return 1
    end

    set -l session_script /home/alex/.config/fish/cage-session.fish
    if test "$mode" = cage
        # Verifica tudo antes de pedir o encerramento do desktop.
        for dependency in cage kitty wlr-randr jq
            if not command -q $dependency
                printf 'Comando necessário não encontrado: %s\n' "$dependency" >&2
                return 1
            end
        end
        if not test -r "$session_script"
            printf 'Script de inicialização não encontrado: %s\n' "$session_script" >&2
            return 1
        end
        set -l cage_kitty_config "$HOME/.config/kitty/kitty-cage.conf"
        if not test -r "$cage_kitty_config"
            printf 'Perfil Kitty do Cage não encontrado: %s\n' "$cage_kitty_config" >&2
            return 1
        end
    end

    if test "$mode" = cosmic
        # O próprio lançador prepara o ambiente gráfico e o bus da sessão.
        for dependency in start-cosmic cosmic-session cosmic-comp
            if not command -q $dependency
                printf 'Comando necessário não encontrado: %s\n' "$dependency" >&2
                return 1
            end
        end
        if not set -q XDG_RUNTIME_DIR; or not test -d "$XDG_RUNTIME_DIR"
            printf '%s\n' 'XDG_RUNTIME_DIR indisponível: entre por um TTY local antes de iniciar o COSMIC.' >&2
            return 1
        end
    end

    set -l dm_state (command systemctl show --property=ActiveState --value sddm.service)
    if test $status -ne 0; or not contains -- "$dm_state" active inactive failed activating deactivating reloading
        printf '%s\n' 'Não foi possível determinar o estado do SDDM; nada foi alterado.' >&2
        return 1
    end

    if not contains -- "$dm_state" inactive failed
        printf '%s\n' 'Isto encerra o desktop e seus aplicativos. Salve seu trabalho antes.'
        set -l confirmation
        read --local --prompt-str 'Digite SIM para encerrar o desktop: ' confirmation
        or return 1
        if test "$confirmation" != SIM
            printf '%s\n' 'Cancelado. Nada foi encerrado.'
            return 1
        end
        command sudo systemctl stop sddm.service
        or return $status
    end

    if test "$mode" = tty
        set -l keymap_file /home/alex/.config/keymaps/us-intl-altgr.map.gz
        if test -f "$keymap_file"
            command sudo loadkeys -u "$keymap_file"
            or return $status
        end
        printf '%s\n' 'Console puro. Use start_graphic --cage ou start_graphic --cosmic quando quiser.'
        return 0
    end

    if test "$mode" = cosmic
        # Roda em primeiro plano no TTY de login; ao sair da sessão, a função retorna.
        # Remove variáveis herdadas de outro compositor, sem iniciar o SDDM.
        printf '%s\n' 'Abrindo COSMIC diretamente. Ao sair do desktop, você volta a este TTY.'
        command env -u DISPLAY -u WAYLAND_DISPLAY -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP \
            XDG_SESSION_TYPE=wayland start-cosmic
        set -l cosmic_status $status
        if test $cosmic_status -ne 0
            printf 'COSMIC encerrou com código %s. Você continua no TTY.\n' "$cosmic_status" >&2
        end
        return $cosmic_status
    end

    # XKB só afeta esta sessão; com o desktop parado, o Cage não precisa de sudo.
    set -lx XKB_DEFAULT_RULES evdev
    set -lx XKB_DEFAULT_MODEL pc105
    set -lx XKB_DEFAULT_LAYOUT us
    set -lx XKB_DEFAULT_VARIANT altgr-intl
    set -lx XKB_DEFAULT_OPTIONS lv3:ralt_switch
    printf '%s\n' 'Abrindo Cage + Kitty no DP-1 a 165 Hz. Fechar o último painel retorna ao TTY.'
    command env -u DISPLAY -u WAYLAND_DISPLAY cage -s -- fish --no-config "$session_script"
    set -l cage_status $status
    if test $cage_status -ne 0
        printf 'Cage encerrou com código %s. Você continua no TTY.\n' "$cage_status" >&2
    end
    printf '%s\n' 'Para abrir COSMIC diretamente: start_graphic --cosmic'
    return $cage_status
end
