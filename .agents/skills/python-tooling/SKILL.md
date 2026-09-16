---
name: python-tooling
description: After writing or editing Python code, run uvx ruff, uvx mypy, and uvx pytest to validate. If the project lacks config files, scaffold minimal ones from templates/. Use when generating, modifying, testing, or reviewing Python files.
---

# Python Tooling Validation Loop

After **every** code change to Python files, run this loop. Never skip a step
unless the tool's config is absent and can't be scaffolded.

## 1. Lint

```bash
uvx ruff check .
```

- If the project has no `ruff.toml` or `[tool.ruff]` in `pyproject.toml`, copy
  `templates/ruff.toml` to the project root first.
- Fix all errors before moving on. Use `uvx ruff check --fix .` for
  auto-fixable issues.

## 2. Type Check

```bash
uvx mypy src/
```

- If the project has no `mypy.ini` or `[tool.mypy]` in `pyproject.toml`, copy
  `templates/mypy.ini` to the project root first.
- If the project has no `src/` directory (single-file scripts), run on `*.py`
  instead: `uvx mypy *.py`

## 3. Test

```bash
uvx pytest -x
```

- If the project has no `pytest.ini` or `[tool.pytest]` in `pyproject.toml`,
  copy `templates/pytest.ini` to the project root first.
- `-x` stops on first failure so you can fix and re-run quickly.

## Workflow

```
Write code → uvx ruff check . → fix → uvx mypy src/ → fix → uvx pytest -x → fix → done
```

If any step fails, fix the errors and re-run that step before moving on. Never
present code as "done" if lint, type checking, or tests are failing.

## Tool Availability

All tools are available via `uvx` (bundled with `uv`). See `.local` for this
system's paths and versions. `uvx` downloads tools on first use and caches them
— no global install needed.

## Scaffolding Missing Configs

If a config file is missing, do NOT silently skip the step. Instead:

1. Copy the template from `templates/` to the project root.
2. Adjust the Python version if needed (`python3 --version`).
3. Run the tool. If it produces nonsensical errors because the template doesn't
   match the project structure, report the problem and ask the user — don't
   force-fit the template.
