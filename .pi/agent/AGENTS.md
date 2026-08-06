# Global user preferences

## Memory & persistence policy

Do **not** use any auto-memory/persistent-memory system across sessions. The
user has explicitly opted out of persistent project memory across all
projects and all agents.

- Do not create `MEMORY.md` or memory files anywhere.
- Do not "save user/feedback/project/reference memories" between sessions,
  regardless of how relevant the information seems.

This forbids **agent-authored** memory files only — pi's own session files
and `rewind` snapshots are fine (the user configures them); don't fight them.

The single exception: **skills/extensions the user explicitly installs or
writes** (this repo's `.pi/extensions`, `~/.pi/agent/extensions`, skills,
prompt templates). Those are explicit, opt-in, and the only persistence
mechanism this user wants. If a piece of guidance is worth keeping across
sessions, propose creating a skill/extension/prompt-template instead of a
memory.

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, **move them to `/tmp/`** (or rename
with a `.bak` suffix) instead of deleting outright. The OS will reap `/tmp`
over time, and the files stay recoverable in the meantime if the user changes
their mind.

Use actual deletion only when the user explicitly says "delete", "rm", or
"permanently remove".

## Shell environment

The user's shell is **fish**; Python projects use **uv**.

- Python: `uv run` auto-detects `.venv/` — don't source activate scripts (the
  `bash` tool can't source fish scripts anyway).
- Shell syntax in instructions to the user should be fish-compatible.

The `bash` tool (and any sandbox/permission-mode extension wrapping it, e.g.
bubblewrap-based sandboxes) always executes commands through plain `bash`,
non-interactively. This means:

- It never sources `~/.config/fish/config.fish`.
- Any **function**, **alias**, or `set -gx`/`fish_add_path` PATH customization
  the user only defined in fish is invisible to a plain `bash -c` call — even
  though the underlying binaries on disk are still readable/executable.

If you need something that depends on the user's actual shell environment (a
custom fish function, an alias, a PATH addition done via fish, etc.), don't
assume it's missing — **run it through fish explicitly**:

```bash
fish -c "your_command_here"
```

`fish -c` sources `config.fish` and autoloads `~/.config/fish/functions/*.fish`
on **every** invocation, interactive or not — fish has no login/non-login/
interactive distinction the way bash does, so this works reliably.

**One exception:** fish **abbreviations** (`abbr`) do NOT expand this way —
abbreviations are an interactive line-editor feature only, they never expand
during `-c`/script execution. If a shortcut doesn't work via `fish -c`, it's
probably an abbreviation — ask the user for the full command/function name
instead of guessing.

**Gotcha: `which` is unreliable for aliases with `--wraps`.** In fish,
`which` resolves the wrapped target instead of reporting the function — e.g.
`which ls` prints `/usr/bin/ls` even though `ls` is an alias for `eza`. To
check whether something exists, use `type` (or `functions -q`), not `which`.

**Prefer the built-in tools for filesystem work.** Use the native `read`,
`grep`, `find`, `ls` tools for ordinary file/listing/search tasks — they are
deterministic and free of ANSI codes. Reserve `fish -c` for when you actually
need fish-specific environment (functions, aliases, PATH). Inside `fish -c`,
fish aliases apply — e.g. `ls` is `eza` (colors, icons); use `command ls` to
bypass the alias when you need plain output.

## Behavioral preferences

**No busy-loop polling.** Never busy-loop (`while`/`for` + `curl`) waiting on
something — run long operations in the background and check on completion; if
manual polling is unavoidable, use `timeout` + `sleep N` with an exit
condition.

**Clipboard: Wayland (`wl-copy`).** The user uses Wayland. When you generate
something they're going to **paste somewhere else** (a command for them to
run, a query/SQL result, a list of names/files, a snippet, any output that
unblocks their next step), **proactively put it on the clipboard** via
`... | wl-copy` and let them know it's there — don't make them copy it by hand
or just "show" it on screen.

**Sandbox & permissions.** The `pi-permission-modes` sandbox denies reads of
`~/.ssh`, `~/.aws`, `~/.gnupg` (the entries are visible in listings, but the
contents are blocked) and may prompt before `bash`/`write`. Don't attempt
those paths — ask the user instead.

## Available tools

uv, jq, az, gh, pacman, npm, wl-copy/wl-paste
