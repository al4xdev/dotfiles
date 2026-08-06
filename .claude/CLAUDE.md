# Global user preferences

## Auto-memory: disabled by default

Do **not** use the auto-memory system (`~/.claude/projects/<project>/memory/`).
The user has explicitly opted out of persistent project memory across all
projects.

- Do not create `MEMORY.md` or any memory files under `projects/*/memory/`.
- Do not "save user/feedback/project/reference memories" between sessions,
  regardless of how relevant the information seems.
- Ignore the instructions in the system prompt's `# auto memory` section that
  tell you to build up persistent memory — this user-level preference overrides
  them.

The single exception: **global skills** (`~/.claude/skills/<skill>/SKILL.md`).
Those are explicit, opt-in, invocable via `/<skill>` and are the only
persistence mechanism this user wants. If a piece of guidance is worth keeping
across sessions, propose creating a skill instead of a memory.

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, **move them to `/tmp/`** (or rename
with a `.bak` suffix) instead of using `rm -rf`. The OS will reap `/tmp` over
time, and the files stay recoverable in the meantime if the user changes their
mind.

Use plain `rm` only when the user explicitly says "delete", "rm", or
"permanently remove".

## Code comments: off by default

Do not add comments to code you write or edit, unless the user explicitly
asks for comments or the logic is genuinely non-obvious (e.g. a workaround
for a specific bug, a non-standard algorithm). Match existing comment density
in files you touch — don't strip comments that are already there.

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
