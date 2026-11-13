# Global user preferences

## Code comments

Comment decisions, constraints, and logic that are not obvious from the code.
Avoid comments that merely repeat what the code does. Match the style of files
you touch and preserve useful existing comments.

## Execution conventions

The shell is the normal way to look at things: `rg`/`grep -rn`, `find`, `ls`, `sed -n`,
`git`.

- Bound every output at the source: `| head -40`, `sed -n 120,180p f`, `grep -m 20`, and
  `2>&1 | tail -30` for builds and tests. Check `wc -l` before printing a file of unknown
  size: an unbounded dump stays in the context for the rest of the session.
- Batch independent looks into one call, separated by `;` (grep a symbol, slice two
  files, list a directory): a probe that finds nothing exits 1 and must not stop the
  others. Use `&&` only where a step needs the previous one (`build && test`).
- Search with a path or glob filter (`rg -n pattern src -g '*.ts'`,
  `grep -rn --include='*.c' pattern src`) and leave vendored and build directories out.
- Issue independent tool calls together in one response, not one per step.
- Use `read` to view an image, or a whole file when you want numbered lines.
- Change files with `edit`/`write`, so the change shows as a diff; `edit` needs only an
  exact, unique snippet. A script is fine for a mechanical rewrite across many files.
- To analyse data (logs, binaries, images, JSON), write a short script and print the
  result, not the data. Process JSON with `jq`.
- Give long builds and test runs a timeout; start servers in the background.

`bash` runs `bash -c`, not the user's interactive shell. Write anything the user will
paste into their own terminal in their shell's syntax.

Package directories under `~/.dsh/profiles` are symlinks into the npx install. `rg` and
`find` do not follow symlinks by default (`rg -L`, `find -L`), so an empty result there
means "not looked", not "absent".

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
  steps (audit → edit). When you need its result before acting, call `wait`
  with a generous duration: it returns as soon as the subagent reports (or the
  user writes), so don't guess, poll or duplicate its work. Without a goal,
  ending the turn works too: the report starts a new turn.
