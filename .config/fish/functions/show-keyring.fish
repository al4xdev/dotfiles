function show-keyring --description "List keyrings and items via the Secret Service (gdbus); --secrets also shows the values"
    set -l base /org/freedesktop/secrets
    set -l show 0
    test "$argv[1]" = "--secrets"; and set show 1

    function __show_keyring_prop --argument-names path iface prop
        gdbus call --session --dest org.freedesktop.secrets --object-path $path \
            --method org.freedesktop.DBus.Properties.Get $iface $prop 2>&1
    end

    function __show_keyring_clean
        string replace -r "^\(<'?(.*?)'?>,\)\$" '$1' -- $argv
    end

    set -l cols (__show_keyring_prop $base org.freedesktop.Secret.Service Collections \
        | grep -oE "/org/freedesktop/secrets/collection/[A-Za-z0-9_]+")

    for c in $cols
        string match -q "*/session" $c; and continue
        set -l label (__show_keyring_clean (__show_keyring_prop $c org.freedesktop.Secret.Collection Label))
        set -l locked (__show_keyring_clean (__show_keyring_prop $c org.freedesktop.Secret.Collection Locked))
        set -l items (__show_keyring_prop $c org.freedesktop.Secret.Collection Items | grep -oE "$c/[0-9]+")
        echo ""
        echo "=== $label  [locked=$locked]  ("(count $items)" refs) ==="
        for it in $items
            set -l lbl (__show_keyring_prop $it org.freedesktop.Secret.Item Label)
            if string match -q "*Error*" -- "$lbl"
                echo "  - broken/ghost item: $it"
                continue
            end
            echo "  - "(__show_keyring_clean $lbl)
            if test $show = 1
                python3 ~/.config/my_scripts/show-keyring-secret.py "$it" 2>/dev/null
                or echo "      (could not read the secret)"
            end
        end
    end

    # remove the local helpers so they don't leak into the global scope
    functions -e __show_keyring_prop __show_keyring_clean
end
