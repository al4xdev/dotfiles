function emudeck-retro --description "Launch EmuDeck AppImage using configurations from retro user"
    # Ensure Wayland permissions are updated for alex session
    if test -n "$WAYLAND_DISPLAY"; and test -n "$XDG_RUNTIME_DIR"
        set -l socket_path "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        if test -e "$socket_path"
            chmod 666 "$socket_path"
            setfacl -m u:retro:x "$XDG_RUNTIME_DIR" 2>/dev/null
            setfacl -m u:retro:rw "$socket_path" 2>/dev/null
        end
    end

    echo "Launching EmuDeck as retro user..."
    run-as-retro /home/retro/Applications/EmuDeck.AppImage $argv
end
