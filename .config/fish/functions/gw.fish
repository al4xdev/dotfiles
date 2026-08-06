function gw --wraps="~/.local/bin/md-kitty" --description "Markdown HD Renderer for Kitty Terminal"
    if test (count $argv) -eq 0
        echo "Uso: gw <arquivo.md>"
        return 1
    end
    ~/.local/bin/md-kitty $argv
end
