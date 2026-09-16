#!/usr/bin/env python3
"""Capture repeatable mobile screenshots and touch flows with Playwright."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from playwright.sync_api import Page, sync_playwright


def parse_size(value: str) -> tuple[int, int]:
    try:
        width, height = (int(part) for part in value.lower().split("x", 1))
    except (TypeError, ValueError) as error:
        raise argparse.ArgumentTypeError("viewport must be WIDTHxHEIGHT") from error
    if width < 240 or height < 320:
        raise argparse.ArgumentTypeError("viewport is implausibly small")
    return width, height


def selector(action: dict[str, Any]) -> str:
    value = action.get("selector")
    if not isinstance(value, str) or not value:
        raise ValueError(f"{action['type']} requires a non-empty selector")
    return value


def swipe(page: Page, action: dict[str, Any]) -> None:
    start = action["start"]
    end = action["end"]
    steps = max(2, int(action.get("steps", 12)))
    duration_ms = max(16, int(action.get("duration_ms", 280)))
    cdp = page.context.new_cdp_session(page)
    cdp.send(
        "Input.dispatchTouchEvent",
        {"type": "touchStart", "touchPoints": [{"x": start[0], "y": start[1]}]},
    )
    for index in range(1, steps):
        fraction = index / steps
        x = start[0] + (end[0] - start[0]) * fraction
        y = start[1] + (end[1] - start[1]) * fraction
        cdp.send(
            "Input.dispatchTouchEvent",
            {"type": "touchMove", "touchPoints": [{"x": x, "y": y}]},
        )
        page.wait_for_timeout(duration_ms // steps)
    cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})


def run_action(page: Page, action: dict[str, Any], output_dir: Path) -> None:
    kind = action.get("type")
    if kind == "wait_for":
        page.locator(selector(action)).wait_for(
            state=action.get("state", "visible"),
            timeout=int(action.get("timeout_ms", 10_000)),
        )
    elif kind == "click":
        page.locator(selector(action)).click()
    elif kind == "fill":
        page.locator(selector(action)).fill(str(action.get("value", "")))
    elif kind == "press":
        page.locator(selector(action)).press(str(action["key"]))
    elif kind == "tap":
        if action.get("selector"):
            page.locator(selector(action)).tap()
        else:
            page.touchscreen.tap(float(action["x"]), float(action["y"]))
    elif kind == "swipe":
        swipe(page, action)
    elif kind == "wait":
        page.wait_for_timeout(int(action.get("ms", 500)))
    elif kind == "screenshot":
        target = output_dir / str(action.get("name", "capture.png"))
        target.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=target, full_page=bool(action.get("full_page", False)))
    elif kind == "evaluate":
        page.evaluate(str(action["expression"]))
    else:
        raise ValueError(f"unsupported action type: {kind!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--actions", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--viewport", type=parse_size, default=(393, 852))
    parser.add_argument("--device-scale-factor", type=float, default=2)
    parser.add_argument("--video", action="store_true")
    parser.add_argument("--headed", action="store_true")
    args = parser.parse_args()

    actions = json.loads(args.actions.read_text(encoding="utf-8"))
    if not isinstance(actions, list):
        raise ValueError("actions JSON must be a list")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    width, height = args.viewport

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=not args.headed)
        context_args: dict[str, Any] = {
            "viewport": {"width": width, "height": height},
            "device_scale_factor": args.device_scale_factor,
            "is_mobile": True,
            "has_touch": True,
            "locale": "en-US",
            "color_scheme": "dark",
        }
        if args.video:
            context_args["record_video_dir"] = args.output_dir
            context_args["record_video_size"] = {"width": width, "height": height}
        context = browser.new_context(**context_args)
        page = context.new_page()
        page.goto(args.url, wait_until="networkidle")
        for action in actions:
            if not isinstance(action, dict):
                raise ValueError("every action must be an object")
            run_action(page, action, args.output_dir)
        video = page.video
        context.close()
        if video:
            video.save_as(args.output_dir / "capture.webm")
        browser.close()

    print(
        json.dumps(
            {
                "url": args.url,
                "viewport": {"width": width, "height": height},
                "device_scale_factor": args.device_scale_factor,
                "touch": True,
                "output_dir": str(args.output_dir),
                "video": args.video,
            }
        )
    )


if __name__ == "__main__":
    main()
