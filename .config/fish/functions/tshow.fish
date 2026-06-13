function tshow --description "Lista todos os aliases temporários ativos na sessão"
    # Checa se a lista existe e se não está vazia
    if not set -q __talias_list; or test (count $__talias_list) -eq 0
        set_color yellow
        echo "Nenhum alias temporário ativo nesta sessão."
        set_color normal
        return 0
    end

    set_color cyan
    echo "📌 Aliases Temporários Ativos:"
    set_color normal

    # Percorre a lista e imprime cada alias com seu comando
    for name in $__talias_list
        # Acesso dinâmico à variável que guarda o comando
        set -l varname __talias_cmd_$name
        echo "   "(set_color yellow)"$name"(set_color normal)" -> "(set_color green)"$$varname"(set_color normal)
    end
end
