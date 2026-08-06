function claude --description "claude CLI with grammar-fix editor wired to ctrl+g"
    EDITOR="$HOME/.local/bin/grammar-fix-editor.sh" command claude $argv
end
