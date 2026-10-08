# Global user preferences

## Code comments

Comment decisions, constraints, and logic that are not obvious from the code.
Avoid comments that merely repeat what the code does. Match the style of files
you touch and preserve useful existing comments.

## Execution conventions

Prefer the native tool over the shell: `read`, `list`, `glob` and `grep` to
inspect, `edit`/`write`/`apply_patch` to change, `trash` to remove,
`clipboard_copy` to hand something back. Keep `bash` for what only a shell can
do — builds, tests, `git`, processes, ports.

Give each call one operation. A script that does a dozen things at once is not
faster, it is opaque: the transcript shows a wall of text instead of a sequence
of decisions, and there is no discrete point to revert. Anything destructive
gets its own call and its own approval.

`bash` runs `bash -c`, not the user's interactive shell. Write anything the user
will paste into their own terminal in their shell's syntax. Use the machine's
own conventions for Python workflow and locations. If machine context is missing
in a legacy instance, inspect the environment instead of inventing facts.

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

- Anchor every requested task in a goal: use `get_goal`, then `create_goal` if
  none is active. Reuse the current goal; resume it with `update_goal` when the
  user asks to continue.
- In plan mode, investigate and submit the complete plan through
  `exit_plan_mode`. Include using the goal to guide execution after approval;
  stay in plan mode until approval.
- Use the actual tools, not code blocks pretending to call them. Keep work
  focused on the goal and mark it complete only after verifying the requested
  result.
