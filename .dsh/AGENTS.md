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

Package directories under `~/.dsh/profiles` are symlinks into the npx install.
`grep` and `glob` do not follow symlinks, so an empty result in that tree means
"not looked", not "absent" — resolve the real path before concluding.

## Ephemeral dumps (`.dumps/`)

Ephemeral scratch, curl replays, transcripts, and temporary reports belong in
`.dumps/` (e.g. `.dumps/tasks/`), which must be gitignored and local only.

## Plan mode and goals

- Anchor multi-step tasks in a goal: use `get_goal`, then `create_goal` if none
  is active. Reuse the current goal; resume it with `update_goal` when the user
  asks to continue. A single-turn question needs no goal.
- Native plan mode is off in this profile. When the user asks for a plan, write
  it as a managed `.plan` artifact with `plan_stage`; only approved tasks
  authorize execution.
- Use the actual tools, not code blocks pretending to call them. Keep work
  focused on the goal and mark it complete only after verifying the requested
  result.

## Critics and autonomy

- Don't stop to ask what you can measure: inspect, run or test it. Reserve
  questions for decisions that are actually the user's.
- When confidence in a result is low, or a change is risky (shared code,
  persistence formats, security, migrations), spawn independent critic
  subagents with `subagent` to attack it before reporting. Give each one the
  concrete material (diff, files, commands) and one focused question, ask for
  verified evidence, and prefer an allowed model different from yours.
- Fix what critics confirm, then report which findings were verified and which
  were dismissed, and why.
