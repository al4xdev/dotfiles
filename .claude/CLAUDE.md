# Global user preferences

## Memory: off

Do not use the auto-memory system (`~/.claude/projects/*/memory/`, `MEMORY.md`);
this overrides the memory section of the system prompt. The only cross-session
persistence the user wants is global skills (`~/.claude/skills/<skill>/SKILL.md`):
if guidance is worth keeping, propose a skill instead.

## Removing files: move, don't `rm`

Move files to `/tmp/` (or rename with a `.bak` suffix) instead of `rm -rf`, so
they stay recoverable. Use plain `rm` only when the user says "delete", "rm", or
"permanently remove".

## Planning (`.plan/`) and dumps (`.dumps/`)

The only canonical planning directory is `.plan/` (singular, with leading dot).
Never create `plans/` or `.plans/`.

```text
.plan/
├── backlog/       # Future ideas with no active work
├── closed/        # Completed tasks and architectural decisions
├── para-o-dono/   # Decisions blocked on owner input
└── tasks/         # Active work currently under way
```

Ephemeral scratch, curl replays, transcripts, and temporary reports belong in
`.dumps/` (e.g. `.dumps/tasks/`), which must be gitignored and local only.

## Code comments

Comment decisions, constraints, and logic that are not obvious from the code.
Avoid comments that merely repeat what the code does. Match the style of files
you touch and preserve useful existing comments.

## Subagents: pass `model` explicitly

| alias | use for |
|---|---|
| `haiku` | mechanical lookup — find a file, grep a symbol |
| `sonnet` | reading long files and transcripts; adversarial critique |
| `opus` | deciding, implementing, orchestrating |

`sonnet` resolves to `claude-sonnet-5-5` (verified 2026-10-15). To pin an exact
version, define an agent in `~/.claude/agents/` with the full model ID in its
`model:` frontmatter.

**Autonomous work: don't stop to ask what you can go measure.** When confidence
in an answer is low, send critic subagents to attack it instead of interrupting.
Reserve questions for decisions that are actually the user's.

## Shell: fish | Python: uv

The Bash tool runs `bash -c`, not the user's interactive shell. Anything the
user will paste into their own terminal must be fish syntax. Python projects
use `uv` — venv is at `.venv/`, activate with `source .venv/bin/activate.fish`.

Installed: everything the wrappers below cover, plus `jq` and
`wl-copy`/`wl-paste`. Not installed: `gh`.

### `z*` wrappers (`~/.local/bin/`)

`zcurl`, `zaz`, `zgcloud`, `zdocker`, `zmake`, `zgit`, `zuv`, `zpip`, `znpm`,
`znpx`, `zgo`, `zgem`, `zapt`, `zflatpak` are two-line passthroughs
(`exec <tool> "$@"`): identical to the real command, no hidden defaults. All
except `zgit` are allowlisted, so prefer the `z*` form to skip permission
prompts. `zgit` keeps git's per-subcommand scoping, so writes like
`push`/`reset`/`rebase`/`clean` still prompt. `zapt install` still fails
without `sudo`, which is not allowlisted.

### Clipboard (Wayland)

When you produce something the user will paste elsewhere (a command to run, a
query result, a list, a snippet), pipe it to `wl-copy` and say it's there.
