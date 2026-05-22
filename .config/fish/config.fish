# ----------------------------------------------------------------------------
# Global Variables
# ----------------------------------------------------------------------------
# Using -eU to erase any previously persisted universal variables,
# avoiding disk writes on every shell startup.
set -eU EDITOR
set -eU VISUAL
set -eU ENVIRONMENT
set -eU fish_greeting
set -eU fish_color_autosuggestion

# ----------------------------------------------------------------------------
# PATH and Environment
# ----------------------------------------------------------------------------
# fish_add_path adds to PATH idempotently (no duplicates)
fish_add_path -g ~/.local/bin

if test -f ~/.cargo/env.fish
    source ~/.cargo/env.fish
end

# ----------------------------------------------------------------------------
# Aliases
# ----------------------------------------------------------------------------
# Replace ls with eza
set -l eza_opts --color=always --group-directories-first --icons
alias ls "eza -al $eza_opts"
alias la "eza -a $eza_opts"
alias ll "eza -l $eza_opts"
alias lt "eza -aT $eza_opts"
alias l. "eza -ald $eza_opts .*"

if not test -x /usr/bin/yay; and test -x /usr/bin/paru
    alias yay paru
end

# Common usage
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
alias hw 'hwinfo --short'
alias ip 'ip -color'
alias jctl 'journalctl -p 3 -xb'
alias psmem 'ps auxf | sort -nr -k 4'
alias psmem10 'ps auxf | sort -nr -k 4 | head -10'
alias rip 'expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'
alias rmpkg 'sudo pacman -Rdd'
alias tarnow 'tar -acf'
alias untar 'tar -zxvf'
alias upd /usr/bin/garuda-update
alias vdir 'vdir --color=auto'
alias wget 'wget -c'

# ----------------------------------------------------------------------------
# Interactive Initialization
# ----------------------------------------------------------------------------
if status --is-interactive
    starship init fish | source
    if type -q fastfetch
        fastfetch
    end
end



