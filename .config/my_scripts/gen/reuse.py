"""Per-request prompt reuse of the running gen model, read from gen's own log.

llama-server logs, for every task: how many prompt tokens it evaluated, how many
it generated, and how many tokens the slot ended with, so

    prompt total = n_tokens at release - generated
    reused       = prompt total - evaluated       (where the prefix stopped matching)

`reused` alone does not say whether cache was lost: a step that appends a large
tool result legitimately evaluates a lot. What matters is how much of the
*previous* slot state survived:

    previous end = previous n_tokens at release (prompt + its generation)
    lost         = previous end - reused          (already-seen tokens re-evaluated)
    fresh        = prompt total - reused          (material this request adds)

lost ≈ 0 means nothing was re-evaluated; a large `lost` is the actual defect.
Read-only: never starts, stops or writes the service.

    python3 -B ~/.config/my_scripts/gen/reuse.py [--run ID] [--follow]
"""
import argparse
import importlib.util
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("gen_state", ROOT / "gen.py")
gen = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gen)

PROMPT = re.compile(r"task (\d+) \| prompt eval time =\s*[\d.]+ ms /\s*(\d+) tokens")
GENERATED = re.compile(r"task (\d+) \|\s+eval time =\s*[\d.]+ ms /\s*(\d+) tokens")
RELEASE = re.compile(r"task (\d+) \| stop processing: n_tokens = (\d+), truncated = (\d+)")
# llama.cpp matches the longest common prefix against the candidate state, so a
# low similarity is only a hint; the release count is the fact.
SIMILARITY = re.compile(r"selected slot by LCP similarity, f_sim_best = ([\d.]+)")


def rows(text):
    """Yield one row per finished task, in log order."""
    prompt, generated, released, pending_similarity = {}, {}, {}, None
    for line in text.splitlines():
        match = SIMILARITY.search(line)
        if match:
            pending_similarity = float(match.group(1))
            continue
        match = PROMPT.search(line)
        if match:
            prompt[match.group(1)] = int(match.group(2))
            continue
        match = GENERATED.search(line)
        if match:
            generated[match.group(1)] = int(match.group(2))
            continue
        match = RELEASE.search(line)
        if not match:
            continue
        task, tokens, truncated = match.groups()
        if task not in prompt:
            pending_similarity = None
            continue  # a task that died before its timing block
        evaluated = prompt[task]
        made = generated.get(task, 0)
        total = int(tokens) - made
        yield {
            "task": int(task), "total": total, "evaluated": evaluated,
            "generated": made, "end": int(tokens), "reused": max(0, total - evaluated),
            "similarity": pending_similarity, "truncated": truncated == "1",
        }
        prompt.pop(task, None)
        generated.pop(task, None)
        pending_similarity = None


def show(row, previous_end):
    lost = max(0, previous_end - row["reused"]) if previous_end is not None else 0
    fresh = max(0, row["total"] - row["reused"])
    note = " TRUNCATED" if row["truncated"] else ""
    if previous_end is None:
        verdict = "  cold start"
    elif lost > 64:
        verdict = f"  LOST {lost}"
    else:
        verdict = ""
    print(
        f"task {row['task']:>5}  prompt {row['total']:>7}  reused {row['reused']:>7}"
        f"  fresh {fresh:>7}  lost {lost:>6}{note}{verdict}"
    )


def main():
    parser = argparse.ArgumentParser(description="Prompt-cache reuse per request, from the gen log.")
    parser.add_argument("--run", help="previous run ID; defaults to the current one")
    parser.add_argument("--follow", action="store_true", help="keep printing new requests")
    options = parser.parse_args()
    controller = gen.Controller()
    run = controller.run_info(options.run) if options.run else controller.current()
    if not run:
        print("gen: no run recorded", file=sys.stderr)
        return 1
    path = controller.state / run["id"] / "output.log"
    if not path.is_file():
        print(f"gen: no log for run {run['id']}", file=sys.stderr)
        return 1
    seen, previous_end = set(), None
    while True:
        text = path.read_text(errors="replace")
        for row in rows(text):
            if row["task"] in seen:
                continue
            show(row, previous_end)
            seen.add(row["task"])
            previous_end = row["end"]
        if not options.follow:
            return 0
        time.sleep(1)


if __name__ == "__main__":
    raise SystemExit(main())
