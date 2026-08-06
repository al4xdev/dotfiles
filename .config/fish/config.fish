# ----------------------------------------------------------------------------
# Global and Local Variables
# ----------------------------------------------------------------------------
# Ranger file manager don't like global EDITOR :P
set -gx EDITOR micro
set -gx ENVIRONMENT micro
alias xdg-open='micro'

if [ "$fish_greeting" != "" ]
    set -U fish_greeting
end

if [ "$fish_color_autosuggestion" != '#aaaaaa' ]
    set -U fish_color_autosuggestion '#aaaaaa'
end

# ----------------------------------------------------------------------------
# PATH and Environment
# ----------------------------------------------------------------------------
# fish_add_path adds to PATH idempotently (no duplicates)

fish_add_path -g ~/.config/my_scripts
fish_add_path -g ~/.local/bin
fish_add_path -g ~/git/my/google-cloud-sdk/bin

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
# Abbreviations
# ----------------------------------------------------------------------------
# fish >= 3.6 no longer persists `abbr -a` via universal vars — must live here
abbr -a dp deepcode

abbr -a gmmax -- ~/.unsloth/llama.cpp/llama-server -m ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-Q4_K_XXL.gguf --model-draft ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/mtp-gemma-4-26B-A4B-it-Q8_0.gguf --spec-type draft-mtp --spec-draft-n-max 4 --port 8080 --host 0.0.0.0 -c 98304 --parallel 1 --flash-attn on --no-context-shift --no-mmap --fit on --fit-ctx 98304 --metrics --jinja --chat-template-file ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/chat_template.jinja --reasoning on --cache-type-k q8_0 --cache-type-v q8_0 --samplers "temperature;top_p;top_k" --temp 1.0 --top-p 0.95 --top-k 64
abbr -a gmno -- ~/.unsloth/llama.cpp/llama-server -m ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-Q4_K_XXL.gguf --model-draft ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/mtp-gemma-4-26B-A4B-it-Q8_0.gguf --spec-type draft-mtp --spec-draft-n-max 4 --port 8080 --host 0.0.0.0 -c 98304 --parallel 1 --flash-attn on --no-context-shift --no-mmap --fit on --fit-ctx 98304 --metrics --jinja --chat-template-file ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/chat_template.jinja --reasoning off --cache-type-k q8_0 --cache-type-v q8_0 --samplers "temperature;top_p;top_k" --temp 1.0 --top-p 0.95 --top-k 64
abbr -a gmmed -- ~/.unsloth/llama.cpp/llama-server -m ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-Q4_K_XXL.gguf --model-draft ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/mtp-gemma-4-26B-A4B-it-Q8_0.gguf --spec-type draft-mtp --spec-draft-n-max 4 --port 8080 --host 0.0.0.0 -c 65536 --parallel 1 --flash-attn on --no-context-shift --no-mmap --fit on --fit-ctx 65536 --metrics --jinja --chat-template-file ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/chat_template.jinja --reasoning on --cache-type-k q8_0 --cache-type-v q8_0 --samplers "temperature;top_p;top_k" --temp 1.0 --top-p 0.95 --top-k 64 --mmproj ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/mmproj-F16.gguf
abbr -a gmlow -- ~/.unsloth/llama.cpp/llama-server -m ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-Q4_K_XXL.gguf --model-draft ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/mtp-gemma-4-26B-A4B-it-Q8_0.gguf --spec-type draft-mtp --spec-draft-n-max 4 --port 8080 --host 0.0.0.0 -c 4096 --parallel 1 --flash-attn on --no-context-shift --no-mmap --fit on --fit-ctx 4096 --metrics --jinja --chat-template-file ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/chat_template.jinja --reasoning off --cache-type-k q8_0 --cache-type-v q8_0 --samplers "temperature;top_p;top_k" --temp 1.0 --top-p 0.95 --top-k 64 --mmproj ~/.cache/huggingface/hub/models--EZForever--gemma-4-26B-A4B-it-qat-uncensored-heretic-UDmerge-GGUF/snapshots/9567a9ca99f1ee12c9d43082c7351f24b4feef63/mmproj-F16.gguf
abbr -a qw -- ~/.unsloth/llama.cpp/llama-server -m ~/.cache/huggingface/hub/models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF/snapshots/5bc3e238d916f48a861bac2f8a1990a0e9b7e98d/Qwen3.6-35B-A3B-MXFP4_MOE.gguf --mmproj ~/.cache/huggingface/hub/models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF/snapshots/5bc3e238d916f48a861bac2f8a1990a0e9b7e98d/mmproj-F16.gguf --port 8080 --host 0.0.0.0 -c 62464 --parallel 1 --flash-attn on --no-context-shift --no-mmap --fit on --fit-ctx 62464 --metrics --jinja --cache-type-k q8_0 --cache-type-v q8_0 --spec-type draft-mtp --spec-draft-n-max 2 --reasoning off

# ----------------------------------------------------------------------------
# Interactive Initialization
# ----------------------------------------------------------------------------
if status --is-interactive
    starship init fish | source
    if type -q fastfetch
        fastfetch
    end
end





# Added by Antigravity CLI installer
set -gx PATH "/home/alex/.local/bin" $PATH


