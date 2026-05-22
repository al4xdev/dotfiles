# ----------------------------------------------------------------------------
# Variáveis Globais
# ----------------------------------------------------------------------------
# Usamos -g (global) e -gx (global export) em vez de -U (universal)
# para evitar gravações em disco a cada abertura do terminal.
set -eUM EDITOR
set -eUM VISUAL
set -eUM ENVIRONMENT
set -eUM fish_greeting
set -eUM fish_color_autosuggestion

# ----------------------------------------------------------------------------
# PATH e Ambiente
# ----------------------------------------------------------------------------
# fish_add_path adiciona ao PATH de forma inteligente e sem duplicar
fish_add_path -g ~/.local/bin

if test -f "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

# ----------------------------------------------------------------------------
# Aliases
# ----------------------------------------------------------------------------
# Substitui ls pelo eza
alias ls 'eza -al --color=always --group-directories-first --icons'
alias la 'eza -a --color=always --group-directories-first --icons'
alias ll 'eza -l --color=always --group-directories-first --icons'
alias lt 'eza -aT --color=always --group-directories-first --icons'
alias l. 'eza -ald --color=always --group-directories-first --icons .*'


if not test -x /usr/bin/yay; and test -x /usr/bin/paru
    alias yay paru
end

# Uso comum
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'
alias ...... 'cd ../../../../..'
alias big 'expac -H M "%m\t%n" | sort -h | nl'
alias dir 'dir --color=auto'
alias egrep 'ugrep -E --color=auto'
alias fgrep 'ugrep -F --color=auto'
alias fixpacman 'sudo rm /var/lib/pacman/db.lck'
alias gitpkg 'pacman -Q | grep -i "\-git" | wc -l'
alias grep 'ugrep --color=auto'
alias grubup 'sudo update-grub'
alias hw 'hwinfo --short'
alias ip 'ip -color'
alias jctl 'journalctl -p 3 -xb'
alias psmem 'ps auxf | sort -nr -k 4'
alias psmem10 'ps auxf | sort -nr -k 4 | head -10'
alias rip 'expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'
alias rmpkg 'sudo pacman -Rdd'
alias tarnow 'tar -acf '
alias untar 'tar -zxvf '
alias upd /usr/bin/garuda-update
alias vdir 'vdir --color=auto'
alias wget 'wget -c '

# ----------------------------------------------------------------------------
# Inicialização Interativa
# ----------------------------------------------------------------------------
if status --is-interactive
    starship init fish | source
    if type -q fastfetch
        fastfetch
    end
end



