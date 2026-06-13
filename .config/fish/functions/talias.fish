function talias --description "Cria um alias temporário para a sessão atual"
    set -l name $argv[1]
    set -l cmd $argv[2..-1]

    if test -z "$name"; or test -z "$cmd"
        echo "Uso: talias <nome> <comando_completo>"
        return 1
    end

    # 1. Cria o alias nativamente no Fish
    alias $name "$cmd"

    # 2. Registra o nome do alias numa lista global da sessão
    if not contains $name $__talias_list
        set -ga __talias_list $name
    end

    # 3. Salva o comando associado para podermos ler depois
    set -g __talias_cmd_$name "$cmd"

    set_color green
    echo "✅ Alias temporário criado: $name -> $cmd"
    set_color normal
end
