# Global User Preferences for Antigravity

## Session Memory: Disabled

- Never create memory files under `.gemini/antigravity/brain/`, MEMORY.md, or
  brain dumps.
- Treat every session as a clean slate.

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, **move them to `/tmp/`** (or rename
with a `.bak` suffix) instead of using `rm -rf`. The OS will reap `/tmp` over
time, and the files stay recoverable in the meantime if the user changes their
mind.

Use plain `rm` only when the user explicitly says "delete", "rm", or
"permanently remove".

## Shell: fish | Python: uv

Use fish syntax. Python projects use `uv` — venv is at `.venv/`, activate with
`source .venv/bin/activate.fish`.

### Avoid busy-loop polling

Never busy-loop (`while`/`for` + `curl`) waiting on something — run it with
`run_in_background: true` and wait for the completion notification; if manual
polling is unavoidable, use `timeout` + `sleep N` with an exit condition.

### Available tools

uv, jq, az, wl-copy/wl-paste

### Clipboard: Wayland (`wl-copy`)

The user uses Wayland. When you generate something they're going to **paste
somewhere else** (a command for them to run, a query/SQL result, a list of
names/files, a snippet, any output that unblocks their next step), **proactively
put it on the clipboard** via `... | wl-copy` and let them know it's there —
don't make them copy it by hand or just "show" it on screen. Especially when you
ask them to run a command: deliver it already piped into `wl-copy`.
