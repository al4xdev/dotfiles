function gw --wraps="~/.config/my_scripts/md-kitty" --description "Markdown HD Renderer for Kitty Terminal"
    if test (count $argv) -eq 0
        echo "Uso: gw <arquivo.md> [--export pdf|png [opcoes]]"
        return 1
    end

    # Sem --export o comportamento e o de sempre: repassa argv cru pro md-kitty.
    if not string match -qr -- '^--export(=.*)?$' $argv
        ~/.config/my_scripts/md-kitty $argv
        return $status
    end

    set -l rest
    set -l fmt
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --export
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set fmt $argv[$i]
                end
            case '--export=*'
                set fmt (string replace -- '--export=' '' $argv[$i])
            case '*'
                set -a rest $argv[$i]
        end
        set i (math $i + 1)
    end

    switch $fmt
        case pdf png
            ~/.config/my_scripts/md-export --format $fmt $rest
            return $status
        case ''
            echo "gw: --export precisa de um formato (ex: gw --export pdf doc.md)" >&2
            return 1
        case '*'
            echo "gw: formato de export desconhecido: $fmt (use: pdf ou png)" >&2
            return 1
    end
end
