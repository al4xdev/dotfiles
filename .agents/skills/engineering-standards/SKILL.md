---
name: engineering-standards
description: Concurrency locks, file I/O patterns, atomic writes, test requirements, plan adherence, and pre-commit checklist. Use when writing, modifying, or reviewing code, implementing features, fixing bugs, refactoring, writing or running tests, or evaluating pull requests in Python, JavaScript, or shell.
---

# Engineering Standards

These rules apply to ALL code you write or modify. They are non-negotiable.

## Concurrency & Thread Safety

- **Every shared mutable resource must have a lock.** If the codebase already has
  a lock pattern (e.g., `asyncio.Lock` for state files), new resources of the
  same kind MUST follow the same pattern. Never introduce a new shared file or
  in-memory store without a corresponding lock.
- **Read-modify-write on files is NOT atomic.** If you load a JSON file, modify
  the data, and write it back, another coroutine/thread can interleave. Always
  wrap the full read→modify→write cycle inside a lock.
- Before writing any function that mutates shared state, ask: "What happens if
  two requests call this concurrently?" If the answer is "data loss or
  corruption", add a lock.

## File I/O & Performance

- **Never read a file from disk inside a loop** when the data doesn't change
  between iterations. Load once before the loop, pass the data down.
- If a function is called frequently with the same arguments (e.g., config
  lookups), consider caching or passing the result as a parameter instead of
  re-reading from disk every call.
- For JSON files used as lightweight databases: load once per request scope, not
  once per operation within the request.

## Atomicity & Error Recovery

- **Group related mutations together.** If two stores must be consistent (e.g., a
  session record and its items in state), both writes should happen within the
  same lock/transaction scope. Never write to store A, then do work, then write
  to store B — if the work fails, A and B are inconsistent.
- Prefer write-to-temp-then-rename (`write → fsync → rename`) over direct
  overwrites for critical data files. This prevents corruption on crash.

## Plan Adherence

When the user provides a plan (in `.plan/`, a markdown file, or inline):

- **Read the entire plan before writing any code.** Confirm you understand each
  step.
- **Implement ALL items in the plan**, not just the easy ones. If a step is
  ambiguous or seems wrong, ask — don't silently skip it.
- **Do not modify the plan file itself** unless the user explicitly asks you to
  update it. The plan is a spec, not your scratch pad.
- After implementation, **verify each plan item** against your changes. List any
  items you did NOT address and explain why.

## Testing

- **Every refactoring or new module must include tests** unless the user
  explicitly says otherwise or the project has zero existing tests.
- At minimum, write tests for:
  - Round-trip correctness (create → read → verify)
  - Idempotency (run twice → same result)
  - Edge cases (empty input, missing keys, concurrent access)
- If you add a migration function, test it with: empty source, already-migrated
  data, and partial data.

## Pre-Commit Self-Review Checklist

Before presenting your changes as complete, verify:

1. **Lock coverage**: Every new shared resource has a lock matching existing
   patterns.
2. **I/O efficiency**: No file reads inside loops where data is static.
3. **Atomicity**: Related writes are in the same transaction scope.
4. **Error paths**: If step N fails, do steps 1..N-1 leave the system in a
   consistent state?
5. **Return values**: Functions return what their docstring/name promises (e.g.,
   "count migrated" should return migrated count, not discovered count).
6. **Scope creep**: Did you modify files outside the task scope (reformatting,
   renaming, "improving" unrelated code)?
7. **Plan items**: Every item in the plan is addressed or explicitly flagged as
   not done.
