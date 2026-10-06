# Global user preferences

## Persistent memory disabled

Do not use or create persistent memories across sessions. Do not enable Codex
memory. If guidance deserves reuse across sessions, propose an explicit global
skill instead of a memory.

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, **move them to `/tmp/`** (or rename
with a `.bak` suffix) instead of using `rm -rf`. The OS will reap `/tmp` over
time, and the files stay recoverable in the meantime if the user changes their
mind.

Use plain `rm` only when the user explicitly says "delete", "rm", or
"permanently remove".

## Code comments: off by default

Do not add comments to code you write or edit, unless the user explicitly asks
for comments or the logic is genuinely non-obvious (e.g. a workaround for a
specific bug, a non-standard algorithm). Match existing comment density in files
you touch — don't strip comments that are already there.

## Shell: fish | Python: uv

Use fish syntax. Python projects use `uv` — venv is at `.venv/`, activate with
`source .venv/bin/activate.fish`.

### Available tools

uv, jq, az, wl-copy/wl-paste

### Clipboard: Wayland (`wl-copy`)

The user uses Wayland. When you generate something they're going to **paste
somewhere else** (a command for them to run, a query/SQL result, a list of
names/files, a snippet, any output that unblocks their next step), **proactively
put it on the clipboard** via `wl-copy` and let them know it's there — don't
make them copy it by hand or just "show" it on screen.

When invoking from an environment that might lack Wayland session variables,
resolve them dynamically:

```bash
WAYLAND_DISPLAY=$(find "/run/user/$(id -u)/" -maxdepth 1 -name "wayland-*" -not -name "*.lock" -printf "%f\n" 2>/dev/null | head -n 1) XDG_RUNTIME_DIR="/run/user/$(id -u)" wl-copy
```

Especially when you ask them to run a command: deliver it already piped into
`wl-copy`.

## Planning directory (`.plan/`) & Dumps (`.dumps/`)

The only canonical planning directory is `.plan/` (singular, with leading dot).
Never create `plans/` or `.plans/`.

```text
.plan/
├── backlog/       # Future ideas with no active work
├── closed/        # Completed tasks and architectural decisions
├── para-o-dono/   # Decisions blocked on owner input
└── tasks/         # Active work currently under way
```

- Ephemeral scratch, curl replays, transcripts, and temporary reports belong in
  `.dumps/` (e.g. `.dumps/tasks/`), which must be gitignored and local only.

## Autonomy and subagents

Treat the requested objective as authorization for the work needed to achieve
it, including relevant dependency installation, network commands, and local
changes. Resolve technical uncertainty through hypotheses, measurement,
experiments, or an independent agent opinion rather than asking the user for
reassurance. Ask the user when a necessary decision, information, or
authorization can only come from them. Make reasoned, reversible decisions and
continue toward the objective or the user's defined acceptance metrics. Do not
impose a fixed iteration or delegation quota; use Astra to reassess a persistent
impasse under the conditions below.

Git work stays local unless the user requests remote Git/GitHub operations in
the session. Local commits, branches, worktrees, and isolated repository copies
are allowed as checkpoints or to parallelize independent features. Preserve
unrelated user changes and keep concurrent agents from editing the same files.

Delegate when there is a concrete benefit; handle trivial tasks directly. Route
delegated work using this table:

| Task                                                                                                                       | Mechanism                       | Model / effort             |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | -------------------------- |
| Exploration, long documents, information extraction, error finding, and independent evaluation of outputs; not programming | MCP `mcp__agy_scout__agy_scout` | Server-configured Gemini   |
| Simple code, mechanical changes, and well-defined tasks                                                                    | Native subagent                 | `gpt-5.6-luna` / `medium`  |
| General coding, debugging, architecture, and code review                                                                   | Native subagent                 | `gpt-5.6-terra` / `medium` |
| Persistent impasse: second opinion before escalating technical uncertainty to the user                                     | Native subagent                 | `gpt-6-astra` / `medium`   |

- For native subagents, use `fork_turns: "none"` and explicit model and effort.
  Send only the objective, essential context, references, and completion
  criteria.
- Request compact results with evidence and unresolved issues; do not bring full
  documents or logs into the main context.
- Discover MCP tools before declaring them unavailable. Do not silently replace
  Gemini with a native subagent.
- Use Gemini as an independent evaluator of texts, proposals, and results from a
  user, stakeholder, or external reviewer perspective, without requiring code
  knowledge. Ask it to find errors, contradictions, gaps, oddities, and unmet
  criteria. Provide the objective, audience, criteria, and output without
  priming it with your own verdict or justification.
- Consult Gemini first when independent evaluation of the output can resolve the
  uncertainty. Invoke Astra only for a persistent impasse, explicitly describing
  the problem, evidence, at least one hypothesis or approach already checked,
  and why it did not resolve the issue. Do not use Astra routinely for
  architecture or review; verify its second opinion before applying it.
