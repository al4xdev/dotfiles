function lid --description 'Mantem o PC acordado com a tampa fechada'
    # Uso: lid [horas|inf]. Padrao: 1 hora (aceita decimal, ex: 0.5). O inibidor some quando o comando termina.
    set -l dur 3600
    if test (count $argv) -gt 0
        if test $argv[1] = inf
            set dur infinity
        else
            set dur (math "$argv[1] * 3600")
        end
    end
    systemd-inhibit --what=handle-lid-switch:sleep:idle --who=lid --why="tampa fechada de proposito" sleep $dur
end