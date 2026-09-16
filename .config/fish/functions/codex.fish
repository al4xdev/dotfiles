function codex --description "Codex CLI with grammar-fix editor and unrestricted local execution"
    EDITOR="$HOME/.config/my_scripts/grammar-fix-editor.sh" command codex --dangerously-bypass-approvals-and-sandbox $argv
end
