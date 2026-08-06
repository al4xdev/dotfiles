function agy --description "agy CLI with grammar-fix editor wired to ctrl+g"
    EDITOR="$HOME/.local/bin/grammar-fix-editor.sh" command agy $argv
end
