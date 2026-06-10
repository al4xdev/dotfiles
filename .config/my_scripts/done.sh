# --- Completion sound: "Secret Discovered" (Zelda NES) ---
SND="$HOME/.config/my_scripts/zelda_secret.wav"

# Play the WAV at reduced volume (40%); ffplay as fallback
mpv --really-quiet --volume=40 --no-video "$SND" 2>/dev/null \
  || ffplay -nodisp -autoexit -loglevel quiet -volume 40 "$SND" 2>/dev/null

echo "    ─────────────────────────"
