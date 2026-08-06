function es-retro --description "Launch ES-DE using configurations and emulators from retro user"
    set -l use_gamescope true
    set -l es_args

    for arg in $argv
        if test "$arg" = "--no-gamescope"
            set use_gamescope false
        else
            set -a es_args "$arg"
        end
    end

    # Ensure Wayland permissions are updated for alex session
    if test -n "$WAYLAND_DISPLAY"; and test -n "$XDG_RUNTIME_DIR"
        set -l socket_path "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        if test -e "$socket_path"
            chmod 666 "$socket_path"
            setfacl -m u:retro:x "$XDG_RUNTIME_DIR" 2>/dev/null
            setfacl -m u:retro:rw "$socket_path" 2>/dev/null
        end
    end

    # Check if gamescope is available and requested
    if test "$use_gamescope" = "true"; and command -sq gamescope
        echo "Launching ES-DE via gamescope (1280x720)..."
        run-as-retro gamescope -W 1280 -H 720 -f -- es-de $es_args
    else
        echo "Launching ES-DE directly..."
        run-as-retro es-de $es_args
    end
end
