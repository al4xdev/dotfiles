# Global user preferences

## Destructive file ops: prefer `/tmp` over `rm`

When clearing files at the user's request, prefer the `trash` tool for
recoverable removal. If unavailable, move the explicitly verified target to
`/tmp/` or rename it with a `.bak` suffix instead of using `rm -rf`.
Never overwrite a recovery entry. `/tmp` may be cleared by the OS or reboot;
recoverability is temporary, not durable backup.

Use plain `rm` only when the user explicitly says "delete", "rm", or
"permanently remove".

## Code comments

Comment decisions, constraints, and logic that are not obvious from the code.
Avoid comments that merely repeat what the code does. Match the style of files
you touch and preserve useful existing comments.

## Execution conventions

Use the native machine context for user-facing shell syntax, Python workflow
and locations. Follow each execution tool's actual shell contract; do not assume
that the user's interactive shell is the tool executor. If machine context is
missing in a legacy instance, inspect the environment instead of inventing facts.

## Proactive clipboard copying

When you generate something the user will **paste somewhere else** (a command,
query/SQL result, list, snippet, or other paste-ready output), **proactively copy
it with `clipboard_copy`** and tell them it is on the clipboard. Do not make them
copy it manually or only show it on screen. The tool accepts text verbatim;
clipboard plumbing is internal. If unavailable in a legacy instance, use a
verified local fallback and never report success without a successful copy.


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

## Plan mode and goals

- Anchor every requested task in a goal: use `get_goal`, then `create_goal` if none is active. Reuse the current goal; resume it with `update_goal` when the user asks to continue.
- In plan mode, investigate and submit the complete plan through `exit_plan_mode`. Include using the goal to guide execution after approval; stay in plan mode until approval.
- Use the actual tools, not code blocks pretending to call them. Keep work focused on the goal and mark it complete only after verifying the requested result.
