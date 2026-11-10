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

Read entire files by default; slice only when targeting exact known lines.

Process JSON with `jq`, not ad-hoc Python (`python -c`, heredoc scripts).

Give each call one operation, so the transcript reads as a sequence of
decisions with discrete points to revert. Anything destructive gets its own
call and its own approval.

`bash` runs `bash -c`, not the user's interactive shell. Write anything the
user will paste into their own terminal in their shell's syntax.

Package directories under `~/.dsh/profiles` are symlinks into the npx install.
`grep` and `glob` do not follow symlinks, so an empty result there means
"not looked", not "absent" — resolve the real path first.

## Ephemeral dumps

Scratch, curl replays, transcripts, and temporary reports go in `.dumps/`
(e.g. `.dumps/tasks/`), gitignored and local only.

## Goals and plans

- Anchor multi-step tasks in a goal: `get_goal`, then `create_goal` if none is
  active; resume with `update_goal` when the user asks to continue. A
  single-turn question needs no goal.
- When the user asks for a plan, write it with `plan_stage`.

## Autonomy and critics

- Don't stop to ask what you can measure: inspect, run or test it. Reserve
  questions for decisions that are actually the user's. Mark work complete
  only after verifying the result.
- When confidence is low or a change is risky (shared code, persistence
  formats, security, migrations), spawn independent critic subagents to attack
  it before reporting. Give each one the concrete material and one focused
  question, ask for verified evidence, and prefer a model different from
  yours. Report which findings were verified and which were dismissed, and why.

## Subagents

- Always run `subagent` in the background (the default) and never set
  `run_in_background: false`: foreground runs are one-shot and cannot be
  continued. Continue a finished subagent with `send_message` for follow-up
  steps (audit → edit). When you need its result before acting, `wait` for
  the notification instead of guessing or duplicating its work.
