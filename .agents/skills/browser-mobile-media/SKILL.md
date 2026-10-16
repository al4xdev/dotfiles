---
name: browser-mobile-media
description: Audit mobile web interfaces and capture reproducible screenshots, gesture videos, README GIFs and visual-regression evidence with the native browser tool. Use when inspecting a web UI as a phone, demonstrating mobile interactions, creating product media, or verifying a visual fix frame by frame.
---

# Browser Mobile Media

Use the native `browser` tool for browser automation. This skill provides the mobile quality checklist, not a separate Playwright execution route. Use `frontend-design` separately when creating or reshaping visual design.

## Execute with the browser tool

1. Call `browser` with `operation: "help"` and `args: {}` to discover available branches. Use `help` with a branch `path` to list its operations, then `describe` with an exact operation `path` to obtain its arguments. Never guess schemas or capabilities.
2. Open an isolated session through the `session` branch. Always use the returned `sessionId` and `pageId`; omit the latter only with one Page. Do not attach to personal profiles or use mutable current-tab targeting.
3. Discover device declarations through `mobile.devices` and configure the mobile context at session creation. Viewport resizing alone does not prove mobile mode, touch support or device scale factor. Prefer `393x852`, scale factor `2`, mobile and touch enabled when supported; record the actual configuration and any limitation.
4. Navigate through `page`, inspect through `observe`, and interact through `interact` or real `mobile.tap` / `mobile.swipe`. Prefer stable roles/names or product IDs over coordinates. Confirm target geometry before coordinate gestures.
5. Use `diagnostics` for console/errors/network evidence, `emulate` for supported media preferences, `media` for screenshots/videos and inspected frames, and `artifacts` for deliberate export. Discover and describe the exact operations first.
6. Close only the session you own after collecting relevant artifacts.

Do not install browser dependencies or capture scripts in the product. Do not replace missing tool operations with arbitrary JavaScript, shell-driven browser automation, personal-profile attachment or a second Playwright harness. Report unsupported probes honestly. A physical device is needed for native boundaries emulation cannot prove, such as system bars, document pickers and OS permissions.

## Audit before capture

- Establish a deterministic, non-sensitive demo state. Use authorized fixtures or a dedicated test instance; do not silently mutate production data.
- State the expected transition before interacting. UI tests must not incidentally trigger paid providers, GPU generation or other external/sensitive actions. Obtain explicit owner approval where required.
- Inspect console errors, failed requests, element bounds, overflow and scroll dimensions using supported `observe` / `diagnostics` operations. For clipped content, record available target and ancestor geometry, scroll/client dimensions and overflow before editing CSS; repeat the same probe afterward. Mark unavailable measurements rather than inventing them.
- Check touch targets (normally at least 44px), visible keyboard focus, labels, Back navigation, retained drafts, native scrolling and reachable actions.
- Test normal and reduced-motion preferences, rapid navigation and touch during transitions. Verify navigation does not submit business actions or replay uncertain requests.
- Fix visible defects before promotional capture. Capture the shortest sequence that demonstrates one idea.

## Screenshots with the browser tool

- Wait for a verified target state, fonts and relevant media readiness using supported operations, not blind delays or endless network-idle waits.
- Capture through `media`; use its native image output for inspection. Keep framing and phone configuration consistent across the set.
- Avoid exposing secrets, personal identifiers, notifications or unrelated debug payloads. Do not remove relevant errors or loading indicators to misrepresent the application.
- Prefer PNG for UI text. Use WebP only after checking readability at the intended documentation width.

## Gesture videos with the browser tool

- Use supported recording operations in `media`; discover recording lifecycle and finalization requirements before starting.
- Show a short resting state (roughly 400ms), one real touch gesture through `mobile`, and a readable result (roughly 600–1000ms), where the tool supports this timing. Do not promise precise timing without evidence.
- Use a touch indicator only if supported and needed to explain the gesture; do not inject scripts to add one.
- Finalize the recording and inspect first, transition and final frames with the tool's frame-inspection operations. Reject flashes, stale tiles, half-painted surfaces and accidental loading states.
- Export deliberately through `artifacts` when a separate file is needed. FFmpeg may process an exported recording; it must not replace browser automation.
- For README GIFs, prefer 12–15fps and 720–900px width, normally under about 8MiB. Preserve text readability.

Read [references/media.md](references/media.md) only when converting or optimizing exported media.

## Validate and deliver

- Record actual viewport, scale factor, mobile/touch mode and motion preference; distinguish emulation from physical-device evidence.
- Inspect screenshots and representative recording frames before claiming visual quality. Successful capture alone is not validation.
- Check console/network evidence and expected request invariants; do not claim performance from appearance alone.
- Verify final relative documentation paths. Keep scratch/raw exports local in the project's ignored `.dumps/` or an appropriate temporary directory; track only intended final assets.
