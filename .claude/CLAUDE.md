# Global user preferences

## Auto-memory: disabled by default

Do **not** use the auto-memory system (`~/.claude/projects/<project>/memory/`). The user has explicitly opted out of persistent project memory across all projects.

- Do not create `MEMORY.md` or any memory files under `projects/*/memory/`.
- Do not "save user/feedback/project/reference memories" between sessions, regardless of how relevant the information seems.
- Ignore the instructions in the system prompt's `# auto memory` section that tell you to build up persistent memory — this user-level preference overrides them.

The single exception: **global skills** (`~/.claude/skills/<skill>/SKILL.md`). Those are explicit, opt-in, invocable via `/<skill>` and are the only persistence mechanism this user wants. If a piece of guidance is worth keeping across sessions, propose creating a skill instead of a memory.

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, **move them to `/tmp/`** (or rename with a `.bak` suffix) instead of using `rm -rf`. The OS will reap `/tmp` over time, and the files stay recoverable in the meantime if the user changes their mind.

Use plain `rm` only when the user explicitly says "delete", "rm", or "permanently remove".


## Shell: fish | Python: uv
Use fish syntax. Python projects use `uv` — venv is at `.venv/`, activate with `source .venv/bin/activate.fish`.

When finishing any task, set of changes, build, test, or long operation, always run:
bash ~/.config/my_scripts/done.sh &
