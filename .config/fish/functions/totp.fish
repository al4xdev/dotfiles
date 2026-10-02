function totp -d "Generate TOTP code from GPG-encrypted Ente/TOTP export via fzf and copy to Wayland clipboard"
    set -l vault "$HOME/.config/ente-tokens.gpg"

    if not test -f "$vault"
        echo "Vault not found at: $vault"
        echo ""
        echo "Setup instructions:"
        echo "1. Export your tokens or decrypt your Ente export."
        echo "2. Encrypt with: gpg -c -o ~/.config/ente-tokens.gpg <file>"
        return 1
    end

    # Decrypt in memory using gpg
    set -l lines (gpg --quiet --decrypt "$vault" 2>/dev/null)
    if test $status -ne 0 -o -z "$lines"
        echo "Failed to decrypt vault or incorrect passphrase."
        return 1
    end

    # Parse and format entries: "Decoded Label | secret | digits"
    set -l menu_items
    for line in $lines
        if string match -rq '^otpauth://' -- $line
            set -l path (string match -r 'otpauth://[^/]+/([^?]+)' -- $line)[2]
            set -l decoded_path (string replace -a '%20' ' ' -- $path)
            set -l decoded_path (string replace -a '%3A' ':' -- $decoded_path)
            set -l decoded_path (string replace -a '%40' '@' -- $decoded_path)

            set -l secret (string match -r '[?&]secret=([A-Za-z0-9]+)' -- $line)[2]
            set -l digits 6
            if string match -rq '[?&]digits=([0-9]+)' -- $line
                set digits (string match -r '[?&]digits=([0-9]+)' -- $line)[2]
            end

            if test -n "$secret"
                set -a menu_items "$decoded_path | $digits | $secret"
            end
        end
    end

    if test (count $menu_items) -eq 0
        echo "No valid otpauth entries found."
        return 1
    end

    # Interactive selection with fzf
    set -l selected (printf "%s\n" $menu_items | fzf --delimiter=' \| ' --with-nth=1 --prompt="TOTP > " --height=40% --reverse)
    if test -z "$selected"
        return 0
    end

    set -l parts (string split ' | ' -- $selected)
    set -l name $parts[1]
    set -l digits $parts[2]
    set -l secret $parts[3]

    # Generate token using oathtool
    set -l code (oathtool --totp -d "$digits" -b "$secret" 2>/dev/null)
    if test $status -ne 0 -o -z "$code"
        echo "Error generating TOTP token for $name"
        return 1
    end

    # Copy to Wayland clipboard
    set -x WAYLAND_DISPLAY (test -n "$WAYLAND_DISPLAY"; and echo "$WAYLAND_DISPLAY"; or echo "wayland-0")
    set -x XDG_RUNTIME_DIR (test -n "$XDG_RUNTIME_DIR"; and echo "$XDG_RUNTIME_DIR"; or echo "/run/user/1000")
    echo -n "$code" | wl-copy

    echo "✅ $name : copied to clipboard "
end
