function claude --description "claude CLI with grammar-fix editor wired to ctrl+g"
    EDITOR="$HOME/.config/my_scripts/grammar-fix-editor.sh" command claude --model claude-opus-5-5 --effort xhigh $argv
end
