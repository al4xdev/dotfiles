# --- INTERATIVIDADE & HISTÓRICO ---
# Se não for uma sessão interativa, não faz nada
case $- in
    *i*) ;;
      *) return;;
esac

# Histórico: ignora duplicados e comandos que começam com espaço
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Atualiza LINES e COLUMNS ao redimensionar a janela
shopt -s checkwinsize

# --- AMBIENTE & PROMPT ---
# Define um prompt simples e colorido
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Habilita cores no ls e grep
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

# Carrega aliases externos se existirem
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

# --- PATH & FERRAMENTAS (Onde estava o problema) ---

# Cargo (Rust)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Local Bin (Cuidado: se o arquivo .local/bin/env não existir ou for bugado, 
# é melhor adicionar o caminho manualmente como abaixo)
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
