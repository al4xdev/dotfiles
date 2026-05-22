---
name: catch_bugs
description: Structured workflow for processing a single code review finding. Use when the user pastes a finding ([BUG], [SMELL], file:line + note). Automatically triggers the 5-phase workflow (read → explain → options → wait → implement). Does NOT stay active between messages — each finding is independent.
version: 2.0.0
---

# catch_bugs — code review finding processor

Structured workflow for ONE code review finding per invocation. Stateless — does not persist between messages.

## When to apply

**Trigger**: User message contains a code review finding in one of these shapes:
- `[BUG] ...`, `[SMELL] ...`, `[NIT] ...`, `[PERF] ...`, `[SEC] ...`
- "apontamento:", "achado:", "review note:"
- `file.py:line` reference + reviewer-style observation

**Non-trigger**: general questions, requests unrelated to a specific finding.

## The workflow (automatic, per finding)

Treat each case as five distinct phases. Do not skip phases. Do not collapse them into a single response.

### 1. Read before reasoning
- Open the cited file at the cited line. Read enough surrounding context to actually understand the code (typically ±20 lines, more if needed).
- Read **dependencies the finding hinges on**: if the apontamento talks about behavior of a helper class, function, or library call, open that file too. Do not infer behavior from the name.
- Verify the finding actually matches the current code — apontamentos can be stale.

**Hard rule**: never explain a finding without having read the cited code in this session. "I know this pattern" is not enough — the reviewer may have missed local context.

### 2. Explain the finding
Write a focused explanation covering:
- **What** the issue is, in concrete terms (not a restatement of the reviewer note).
- **Why** it matters — what breaks, when, and under which conditions.
- **Whether the reviewer is correct.** If the finding is wrong, partially wrong, or context-dependent, say so explicitly. Do not silently agree to look polite.
- Cite code locations as `path/to/file.py:line` so the user can navigate.

Tone: technical, concise, peer-level. The user has senior context — skip the basics.

### 3. Propose options
Lay out 1–3 viable approaches with trade-offs:
- **(a) minimum** — smallest change that addresses the finding.
- **(b) medium** — addresses finding + closely related cleanup.
- **(c) deeper** — structural change if the finding hints at a broader smell.

Recommend one and say why. If "do nothing" is a legitimate option (reviewer wrong, smell only matters under hypothetical conditions, etc.), include it.

### 4. Wait for direction
**Do not edit code in this turn.** End the response with a clear handoff: "sigo com (a)?" / "qual prefere?" / "quer que eu corrija ou só documente?".

The user will pick a direction, push back, ask deeper questions, or redirect. Only after they confirm, proceed to phase 5.

### 5. Implement minimally and close
- Make the change. Keep scope tight to what was confirmed — no surrounding cleanup, no opportunistic refactor, no "while I was here" edits.
- **Commit locally** using this template:
```bash

**Variables:**
  - `<type>`: `fix` | `refactor` | `docs` | `test` | `perf`
    - Use `fix` for bugs ([BUG] findings)
    - Use `refactor` for smells ([SMELL], [NIT] findings)
    - Use `perf` for performance issues ([PERF] findings)
  - `<scope>`: filename without extension (e.g., `tef`, `auth`, `pipeline`)
  - `<action>`: imperative verb (add, remove, extract, isolate, fix, handle, update)
  - `<target>`: what was changed (e.g., "join key columns", "null check", "retry logic")
  - `<finding-tag>`: copy the exact finding title from the apontamento
  
  **Rules:**
  - Lowercase first letter
  - No period at end
  - Max 72 chars (truncate finding-tag if needed)
  - Imperative mood ("add" not "added")

  **Command:**
```bash

- Brief closing summary (1–3 lines): what changed, where, and any non-obvious follow-up.
- End with "caso fechado" or equivalent. **Do not volunteer the next case.** Wait for the user to paste it.


## Behavioral rules (per finding)

- **One case at a time.** If the user pastes multiple findings in one message, ask which to start with rather than batching.
- **Honesty over agreement.** If you change your mind mid-discussion (e.g., after reading a dependency), say so explicitly and revise. The user has corrected past sessions where assumptions were stated as facts — verify before asserting.
- **No premature implementation.** Even for trivially small fixes, walk through phases 2–4 before editing. The point of the mode is the discussion, not just the patch.
- **No scope creep.** A `[SMELL]` about one method does not authorize fixing similar smells elsewhere. Note them if relevant, but only act on what was raised.
- **Silent between cases.** After closing a case, do not summarize the session, do not propose next steps, do not offer scheduled follow-ups. Just wait.


## Project-specific carve-outs

Some repositories define their own carve-outs (cases where a generic `[SMELL]` is consciously rejected as project convention). **Before tagging a finding**, check if the current repo has a canonical style document:

1. **`AGENTS.md`** at the repo root — convention for agents/LLMs (Cursor, Codex, Claude, Aider). Often points to a `style.MD`.
2. **`CLAUDE.md`** at the repo root — Claude-specific instructions, usually auto-loaded. Often points to the same `style.MD`.
3. **`documentation/style.MD`** (or `STYLE.md` at the root) — common location for the canonical style guide.

If any of those exist, **Read them in phase 1** alongside the cited file. They override generic anti-patterns for that repo. The agentic-billing/databricks repo, for example, has a `documentation/style.MD` with carve-outs for data-pipeline code (column key repetition, prefix-based column classification, staged constructor + factory + chained API, no-orchestrator pipeline, inline `_run_hN` handlers).

If no such document exists, fall back to the generic data-pipeline rules: literal column names repeated in selects/joins/groupBys are not smells when occurrences differ in order/composition; centralizing keys that aren't iterated programmatically usually hurts readability more than it helps.

## Anti-patterns (do not do these)

- Reading only the cited line without surrounding context, then explaining from generic pattern knowledge.
- Asserting behavior of a helper (`SomeClass.foo()`) without reading its source — especially for async/lazy/Spark/Databricks behavior, where the name often misleads.
- Jumping straight from "here is the bug" to an `Edit` call.
- Bundling multiple fixes into one turn because they "look related".
- Agreeing the reviewer is right when the code already handles the case, just to keep moving.
- Adding tests, docstrings, or refactors that were not part of the confirmed direction.

## Between findings

After closing a case, DO NOT:
- Stay in "mode" — next message is fresh
- Summarize the session
- Propose what to tackle next

Just close. If the next message is another finding, re-trigger the workflow.
