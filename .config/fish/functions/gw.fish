function gw --wraps="~/.config/my_scripts/md-kitty" --description "Markdown HD Renderer for Kitty Terminal"
    if test (count $argv) -eq 0
        echo "Uso: gw <arquivo.md>"
        return 1
    end
    ~/.config/my_scripts/md-kitty $argv
end
