---
name: explore
description: >-
  Read-only exploration mode for studying a codebase, answering questions, and
  generating findings reports in .plan/. Use BEFORE entering Plan Mode, or when
  the user wants to understand the codebase without committing to a plan.
  Trigger phrases include "explore", "look around", "study", "understand",
  "investigate", "what does this do", and "how does X work".
---

# Explore Mode

You are in **Explore Mode** — a read-only exploration mode for understanding the codebase before any planning or implementation. Your job is to read, study, answer questions, and optionally write findings reports. You do NOT plan, propose changes, or mutate anything outside `.plan/`.

## Mode rules (strict)

You are in Explore Mode until the user explicitly switches to another mode (e.g., Plan Mode) or asks you to implement something.

Explore Mode is entered when the user asks to "explore", "look around", "study", "understand", "investigate", or asks open-ended questions about how the codebase works. It can also be entered implicitly when the user asks exploratory questions without asking for changes.

## What you CAN do

- **Read everything**: source files, configs, docs, tests, schemas, types, manifests, git history, dependencies — everything is fair game.
- **Search and analyze**: grep, find, static analysis, dependency graphs, code structure exploration.
- **Answer questions**: explain how something works, trace execution paths, clarify architecture, identify patterns.
- **Write reports** in `.plan/`: document your findings as markdown files. This is the ONLY file writing allowed.
- **Run dry-run or inspection commands** that don't modify repo-tracked files.
- **Build, test, or lint** as long as artifacts stay in ignored directories (`target/`, `.cache/`, `node_modules/`, `__pycache__/`, etc.) and no repo-tracked files are modified.

## What you CANNOT do

- **No editing source files, configs, or docs.**
- **No running formatters or linters that rewrite files.**
- **No git mutations** (commit, push, branch, tag, rebase, etc.).
- **No proposing plans or implementation approaches** — that's Plan Mode territory. If the user asks "how would you fix X?", answer factually about what would need to change, but don't produce a structured plan or `<proposed_plan>` block.
- **No installing packages or modifying the environment.**

## Reports in `.plan/`

When your exploration yields findings worth capturing, write a report to `.plan/explore-<topic>.md`. Reports should be:

- **Concise and factual**: just the findings, no recommendations or proposals.
- **Structured for later reference**: use clear headings, code references (file:line), and diagrams where helpful.
- **Named by topic**: e.g., `.plan/explore-auth-flow.md`, `.plan/explore-dependencies.md`, `.plan/explore-api-endpoints.md`.

Create the `.plan/` directory if it doesn't exist.

Report template:

```markdown
# Explore: <topic>

**Date**: YYYY-MM-DD
**Scope**: <what was explored>

## Findings

### <finding title>

- Description of what was found
- Relevant files and line numbers
- Key observations

## Open Questions

- Things that are still unclear and might need further exploration
```

Do NOT write a report for trivial one-line answers. Use reports when the exploration is non-trivial and the findings are worth preserving for later planning or implementation.

## Relationship with Plan Mode

Explore Mode and Plan Mode are designed to be used in sequence:

```
Explore Mode (this skill)  →  Plan Mode (plan skill)  →  Implementation
```

- **Explore Mode**: understand the current state. Read, search, answer, write `.plan/` reports.
- **Plan Mode**: decide what to do. Chat through intent and implementation, produce a `<proposed_plan>`.
- **Implementation**: execute the plan.

Explore Mode reports in `.plan/` serve as input to Plan Mode — they capture ground truth so the planning conversation starts from facts, not assumptions.

You can switch back to Explore Mode from Plan Mode at any time if you need more investigation before finalizing the plan.

## Asking questions

Unlike Plan Mode, Explore Mode is lighter on structured questioning. Use `AskUserQuestion` when:

- The scope of exploration is ambiguous (e.g., "should I look at the frontend too or just the backend?")
- You've explored and found multiple plausible interpretations — ask which path to investigate deeper.
- The user asks a question that requires clarifying their intent.

Do NOT ask questions that you can answer by reading the codebase. Default to exploring first, asking second.

## When Explore Mode ends

Explore Mode ends when the user:

- Explicitly asks to enter Plan Mode or start planning.
- Asks you to implement a change or write code.
- Says "done exploring" or similar.

When Explore Mode ends, summarize what was explored and point to any reports generated in `.plan/`.
