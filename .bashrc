# --- INTERACTIVITY & HISTORY ---
# If not running interactively, do nothing
case $- in
    *i*) ;;
      *) return;;
esac

# History: ignore duplicates and commands starting with a space
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Update LINES and COLUMNS on window resize
shopt -s checkwinsize

# --- ENVIRONMENT & PROMPT ---
# Simple colored prompt
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable colors for ls and grep
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# --- ALIASES ---
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Load external aliases if present
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# --- AUTO-COMPLETION ---
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# --- PATH & TOOLS ---

# Cargo (Rust)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Local bin
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
