function dsh --description "DSH TUI com descoberta opcional do modelo local"
    set -l data_home "$HOME/.local/share"
    if set -q XDG_DATA_HOME; and test -n "$XDG_DATA_HOME"
        set data_home "$XDG_DATA_HOME"
    end
    set -l cli_dir "$data_home/dsh-cli"
    set -lx PATH "$cli_dir/node_modules/.bin" $PATH
    set -lx STRATA_API_KEY local
    set -lx NODE_ENV production
    set -lx DSH_TUI_LANG en
    command node "$cli_dir/local-model-launch.mjs" $argv
end
