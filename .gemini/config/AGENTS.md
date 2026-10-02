# Global user preferences

## Brain / Persistent memory: disabled by default

Do **not** use persistent session memory or brain dumps.
The user has opted out of persistent memory across sessions.

- Treat every session as a clean slate.
- Do not create persistent memory files (`MEMORY.md`, memory dumps, or cross-session logs) under `brain/` or `.gemini/`. Artifacts created under the conversation brain directory should only be temporary session outputs/plans when explicitly relevant to the active task.
- The single exception: **global skills** (`~/.gemini/config/skills/<skill>/SKILL.md`). Those are explicit, opt-in, invocable skills and are the only persistence mechanism. If guidance is worth keeping across sessions, propose creating a skill instead.

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, **move them to `/tmp/`** (or rename with a `.bak` suffix) instead of using `rm -rf`. The OS will reap `/tmp` over time, and the files stay recoverable in the meantime if the user changes their mind.

Use plain `rm` only when the user explicitly says "delete", "rm", or "permanently remove".

## Code comments: off by default

Do not add comments to code you write or edit, unless the user explicitly asks for comments or the logic is genuinely non-obvious (e.g. a workaround for a specific bug, a non-standard algorithm). Match existing comment density in files you touch — don't strip comments that are already there.

## Shell: fish | Python: uv

Use fish syntax. Python projects use `uv` — venv is at `.venv/`, activate with `source .venv/bin/activate.fish`.

### Avoid busy-loop polling

Never busy-loop (`while`/`for` + `curl`) waiting on something — run it with `run_in_background: true` and wait for the completion notification; if manual polling is unavoidable, use `timeout` + `sleep N` with an exit condition.

### Available tools

uv, jq, az, wl-copy/wl-paste

### Clipboard: Wayland (`wl-copy`)

The user uses Wayland. When you generate something they're going to **paste somewhere else** (a command for them to run, a query/SQL result, a list of names/files, a snippet, any output that unblocks their next step), **proactively put it on the clipboard** via `... | wl-copy` (with `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR=/run/user/1000`) and let them know it's there — don't make them copy it by hand or just "show" it on screen. Especially when you ask them to run a command: deliver it already piped into `wl-copy`.
