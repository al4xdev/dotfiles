#!/usr/bin/env bash
#
# keyring-unlock-startup.sh
# Runs at login (via ~/.config/autostart/keyring-unlock-startup.desktop).
#
# Why this exists: when you log in by FINGERPRINT, PAM never receives your
# password, so the "Default keyring" is not unlocked automatically. This script
# writes/updates an item (the login date/time) INSIDE the Default keyring. That
# write forces GNOME to ask for the keyring password once, and the keyring stays
# unlocked for the rest of the session.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Rotating keyring backup
#
# On every login we snapshot the keyring files into a timestamped subdirectory
# under ~/.local/share/keyring-backups/. We keep at most the 10 newest
# snapshots and delete the older ones.
#
# IMPORTANT: backups live OUTSIDE ~/.local/share/keyrings/ on purpose, so that
# gnome-keyring-daemon never tries to read our backup copies as real keyrings.
#
# This runs before the unlock step (it captures the keyring state at the very
# start of the login). It is best-effort: any missing file/dir is skipped and
# never aborts the script, so the unlock below always still runs.
# ---------------------------------------------------------------------------
backup_keyring() {
    local keyrings_dir="$HOME/.local/share/keyrings"
    local backups_dir="$HOME/.local/share/keyring-backups"
    local max_backups=10

    # Nothing to back up if the keyrings directory does not exist yet.
    [ -d "$keyrings_dir" ] || return 0

    # Files we preserve: ALL keyrings (e.g. Login.keyring / Default_keyring.keyring),
    # the default pointer, and the PKCS#11 keystore. Only existing ones are copied.

    # Create a fresh timestamped destination, e.g. 2026-06-10_103000.
    local stamp dest
    stamp="$(date +%Y-%m-%d_%H%M%S)"
    dest="$backups_dir/$stamp"
    mkdir -p "$dest"

    # Copy each existing source, preserving permissions/timestamps (cp -a keeps
    # the 600 mode on the keyring files). Missing files are simply skipped.
    local src copied=0
    for src in "$keyrings_dir"/*.keyring "$keyrings_dir/default" "$keyrings_dir/user.keystore"; do
        if [ -e "$src" ]; then
            cp -a "$src" "$dest/" && copied=$((copied + 1))
        fi
    done

    # If nothing was copied (e.g. all sources missing), drop the empty dir.
    if [ "$copied" -eq 0 ]; then
        rmdir "$dest" 2>/dev/null || true
        return 0
    fi

    # Rotation: keep only the newest $max_backups snapshots, delete the rest.
    # List immediate subdirectories of the backups dir, sorted oldest->newest by
    # name (timestamp names sort chronologically), then remove everything beyond
    # the last $max_backups entries. We rm -rf strictly inside $backups_dir.
    local entries=()
    while IFS= read -r entry; do
        entries+=("$entry")
    done < <(find "$backups_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)

    local count="${#entries[@]}"
    if [ "$count" -gt "$max_backups" ]; then
        local remove=$((count - max_backups))
        local i name target
        for ((i = 0; i < remove; i++)); do
            name="${entries[$i]}"
            target="$backups_dir/$name"
            # Safety guard: only delete real directories that live directly
            # inside the backups dir (never follow anything outside it).
            if [ -d "$target" ] && [ "$(dirname "$target")" = "$backups_dir" ]; then
                rm -rf "$target"
            fi
        done
    fi
}

# Best-effort backup: do not let a backup failure abort the unlock below.
backup_keyring || true

# wait for the graphical session + gnome-keyring + prompter (gcr) to be ready
sleep 8

python3 "$HOME/.config/my_scripts/keyring-unlock-startup.py" \
    "$HOME/.config/my_scripts/.keyring-unlock.log"
