---
name: playwright-mobile-media
description: Automate and audit mobile web interfaces with Playwright, including touch gestures, reproducible screenshots, short videos, README GIFs, visual-regression evidence, console/network inspection, and viewport-specific bug reproduction. Use when Codex needs to inspect a web UI as a phone, demonstrate mobile interactions, create polished product media, or verify a visual fix frame by frame.
---

# Playwright Mobile Media

Use a real mobile browser context and capture only states verified in the running application.
Keep capture harnesses outside the product unless the user requests a maintained test.

## Choose the execution route

1. Prefer a connected Playwright MCP when its browser tools are available.
   - Discover tools with a Playwright-specific search.
   - Navigate, take an accessibility snapshot, then interact through stable roles/names.
   - Use screenshots for evidence; use `run_code` only when ordinary tools cannot express the
     interaction.
2. Use Python Playwright for video, deterministic sequences, or when MCP is unavailable.
   - In a uv project, run `uv run playwright install chromium` once if the browser is absent.
   - Use `scripts/mobile_capture.py` with a JSON action file for repeatable touch flows.
3. Use a physical device only for native-shell boundaries browser emulation cannot prove, such as
   system bars, document pickers, permissions, and activity restarts.

The Claude Playwright plugin that inspired this workflow only launches Microsoft's
`@playwright/mcp`; do not copy its cache or depend on Claude-specific paths.

## Audit before capture

1. Establish a deterministic demo state with non-sensitive data.
2. Fix visible defects before producing promotional media.
3. Use one canonical phone viewport unless requirements specify another: `393x852`, device scale
   factor `2`, touch enabled, mobile enabled.
4. Inspect console errors, failed requests, element bounds, overflow, and scroll dimensions.
5. Pre-register the expected state or transition.
6. Capture the shortest sequence that demonstrates one idea.

For clipped content, record `getBoundingClientRect()`, `scrollHeight`, `clientHeight`, computed
`overflow`, and ancestor bounds before editing CSS. Re-run the same probe after the fix.

## Produce screenshots

- Prefer role/name locators or stable product IDs over coordinates and CSS ancestry.
- Wait for the target state, fonts, images, and relevant network activity.
- Hide update banners, personal session names, secrets, and unrelated debug payloads.
- Use PNG for UI text and WebP only after comparing readability at README width.
- Keep framing consistent across a media set.

## Produce gesture clips

- Show the resting state for roughly 400 ms, perform one gesture, and hold the result for
  600-1000 ms.
- Render a visible touch indicator only when the gesture would otherwise be ambiguous.
- Record WebM with Playwright, then trim and convert with ffmpeg.
- Prefer 12-15 fps and 720-900 px width for README GIFs. Keep each clip under about 8 MiB.
- Inspect the first, transition, and final frames. Reject flashes, stale tiles, half-painted
  surfaces, and accidental loading states.

Read [references/media.md](references/media.md) when converting or optimizing captured media.

## Run the reusable capturer

Create an action JSON in `/tmp`, then run:

```bash
uv run python ~/.codex/skills/playwright-mobile-media/scripts/mobile_capture.py \
  --url http://127.0.0.1:8889 \
  --actions /tmp/mobile-actions.json \
  --output-dir /tmp/mobile-capture \
  --video
```

Supported actions are `wait_for`, `click`, `fill`, `press`, `tap`, `swipe`, `wait`, `screenshot`,
and `evaluate`. Prefer semantic selectors. Use `evaluate` only for read-only probes or explicit
test setup that cannot be reached through the public UI.

## Validate the result

- Confirm viewport and touch mode in the capture log.
- Review screenshots at original resolution.
- Extract representative video frames and compare transition frames.
- Verify every relative documentation media path.
- Keep raw recordings in `/tmp`; track only final optimized assets.
