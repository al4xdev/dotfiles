from __future__ import annotations

import asyncio
import json
import os
import signal
import sys
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / ".agy-runs"
AGY = os.environ.get("AGY_BIN", "/home/alex/.local/bin/agy")
CODEX = os.environ.get("CODEX_BIN", "codex")
TOOLS = [
    {"name": "agy_scout", "description": "Dispatch a long-context agy scout.", "inputSchema": {"type": "object", "properties": {"prompt": {"type": "string"}, "cwd": {"type": "string"}}, "required": ["prompt"]}},
    {"name": "agy_followup", "description": "Send a follow-up to an active scout.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "prompt": {"type": "string"}}, "required": ["run_id", "prompt"]}},
    {"name": "agy_status", "description": "Read scout process state. Events are returned only when tail is requested.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "tail": {"type": "integer", "default": 0}}, "required": ["run_id"]}},
    {"name": "agy_wait", "description": "Wait for a scout to finish without returning intermediate events. Returns immediately on completion or after timeout_seconds.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "timeout_seconds": {"type": "number", "default": 300}}, "required": ["run_id"]}},
    {"name": "agy_interrupt", "description": "Interrupt a scout while preserving its conversation ID.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "force": {"type": "boolean"}}, "required": ["run_id"]}},
    {"name": "agy_continue", "description": "Continue an interrupted scout by conversation ID.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "prompt": {"type": "string"}}, "required": ["run_id", "prompt"]}},
]


@dataclass
class Session:
    run_id: str
    process: asyncio.subprocess.Process | None
    input_file: asyncio.StreamWriter | None
    log_path: Path
    conversation_id: str | None = None
    events: list[dict] = field(default_factory=list)
    diagnostics: list[str] = field(default_factory=list)
    terminal: str | None = None
    done: asyncio.Event = field(default_factory=asyncio.Event)


sessions: dict[str, Session] = {}
lock = asyncio.Lock()


def _five_hour_window(snapshot: dict[str, Any]) -> dict[str, Any] | None:
    """Keep only the five-hour bucket from an app-server usage response."""
    limits = snapshot.get("rateLimitsByLimitId") or {}
    codex = limits.get("codex") or snapshot.get("rateLimits") or {}
    if codex.get("limitId") not in (None, "codex"):
        return None
    for window in (codex.get("primary"), codex.get("secondary")):
        if not isinstance(window, dict) or window.get("windowDurationMins") != 300:
            continue
        used = window.get("usedPercent")
        reset = window.get("resetsAt")
        if not isinstance(used, int) or not isinstance(reset, int):
            return None
        remaining = max(0, min(100, 100 - used))
        usage = {
            "remaining_percent": remaining,
            "resets_at": datetime.fromtimestamp(reset, UTC).isoformat(),
        }
        if remaining <= 5 and reset > datetime.now(UTC).timestamp():
            usage["recommendation"] = (
                "Avise o usuário, aguarde de forma interrompível até resets_at, "
                "consulte o limite novamente e retome a tarefa pendente."
            )
        return usage
    return None


async def _codex_5h_usage() -> dict[str, Any] | None:
    """Ask the installed Codex app-server for a fresh, read-only usage snapshot."""
    process: asyncio.subprocess.Process | None = None
    try:
        process = await asyncio.create_subprocess_exec(
            CODEX, "app-server", "--stdio", stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
        )
        assert process.stdin is not None and process.stdout is not None
        requests = (
            {"id": 1, "method": "initialize", "params": {
                "clientInfo": {"name": "agy-scout", "version": "0.1.0"}, "capabilities": {},
            }},
            {"id": 2, "method": "account/rateLimits/read", "params": {
                "excludeResetCreditDetails": True,
            }},
        )
        for request in requests:
            process.stdin.write((json.dumps(request) + "\n").encode())
            await process.stdin.drain()
            while line := await asyncio.wait_for(process.stdout.readline(), timeout=5):
                response = json.loads(line)
                if response.get("id") == request["id"]:
                    if response.get("error"):
                        return None
                    if request["id"] == 2:
                        return _five_hour_window(response.get("result") or {})
                    break
    except (OSError, ValueError, TimeoutError, json.JSONDecodeError):
        return None
    finally:
        if process is not None and process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), timeout=1)
            except TimeoutError:
                process.kill()
                await process.wait()
    return None


def _meta_path(run_id: str) -> Path:
    return RUNS / f"{run_id}.meta.json"


def _save_meta(session: Session) -> None:
    meta = _meta_path(session.run_id)
    temporary = meta.with_suffix(".tmp")
    temporary.write_text(json.dumps({
        "run_id": session.run_id, "conversation_id": session.conversation_id,
        "log": str(session.log_path),
    }) + "\n")
    temporary.replace(meta)


def _load_session(run_id: str) -> Session:
    meta = _meta_path(run_id)
    if meta.exists():
        data = json.loads(meta.read_text())
        log_path = Path(data["log"])
        conversation_id = data.get("conversation_id")
    else:
        log_path = RUNS / f"{run_id}.jsonl"
        conversation_id = None
    session = Session(run_id, None, None, log_path, conversation_id)
    if session.log_path.exists():
        for line in session.log_path.read_text(errors="replace").splitlines():
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                session.diagnostics.append("protocol_error: persisted stdout line was not valid JSON")
                continue
            session.events.append(event)
            if event.get("event") == "init" and not session.conversation_id:
                session.conversation_id = event.get("conversation_id")
            if event.get("event") == "result":
                session.terminal = event.get("result", {}).get("status", "completed")
                session.done.set()
    return session


def _message(prompt: str) -> bytes:
    return (json.dumps({"event": "user", "message": {"role": "user", "content": prompt}}) + "\n").encode()


async def _reader(session: Session, process: asyncio.subprocess.Process) -> None:
    assert process.stdout is not None
    with session.log_path.open("ab") as log:
        while True:
            line = await process.stdout.readline()
            if not line:
                break
            log.write(line)
            log.flush()
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                session.diagnostics.append("protocol_error: stdout line was not valid JSON")
                continue
            session.events.append(event)
            if event.get("event") == "init":
                session.conversation_id = event.get("conversation_id")
                _save_meta(session)
            if event.get("event") == "result" and session.process is process:
                session.terminal = event.get("result", {}).get("status", "completed")
                session.done.set()
        if session.process is process and session.terminal is None:
            session.terminal = "process_error"
            session.done.set()


async def _stderr_reader(session: Session, process: asyncio.subprocess.Process) -> None:
    assert process.stderr is not None
    while True:
        line = await process.stderr.readline()
        if not line:
            return
        session.diagnostics.append(line.decode(errors="replace").rstrip())


async def _send(session: Session, prompt: str) -> None:
    if session.process is None or session.process.returncode is not None or session.input_file is None:
        raise ValueError("scout process is not accepting input; use agy_continue after interruption")
    session.input_file.write(_message(prompt))
    await session.input_file.drain()


async def agy_scout(prompt: str, cwd: str | None = None) -> dict:
    """Dispatch a long-context scout and return compact status plus its ID."""
    RUNS.mkdir(exist_ok=True)
    run_id = uuid.uuid4().hex[:12]
    log_path = RUNS / f"{run_id}.jsonl"
    process = await asyncio.create_subprocess_exec(
        AGY, "--model", "gemini-3.8-flash-high", "--effort", "high",
        "--output-format", "stream-json", "--input-format", "stream-json",
        "--dangerously-skip-permissions", cwd=cwd or str(ROOT),
        stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    assert process.stdin is not None and process.stdout is not None
    session = Session(run_id, process, process.stdin, log_path)
    async with lock:
        sessions[run_id] = session
    asyncio.create_task(_reader(session, process))
    asyncio.create_task(_stderr_reader(session, process))
    await _send(session, prompt)
    for _ in range(100):
        if session.conversation_id or process.returncode is not None:
            break
        await asyncio.sleep(0.05)
    return {"run_id": run_id, "conversation_id": session.conversation_id, "status": "running", "log": str(log_path)}


async def agy_followup(run_id: str, prompt: str) -> dict:
    """Queue a follow-up for the next input window of an active scout."""
    session = sessions.get(run_id) or _load_session(run_id)
    sessions[run_id] = session
    await _send(session, prompt)
    return {"run_id": run_id, "conversation_id": session.conversation_id, "status": "sent"}


async def agy_status(run_id: str, tail: int = 0) -> dict:
    """Return state; include compact events only when explicitly requested."""
    session = sessions.get(run_id) or _load_session(run_id)
    sessions[run_id] = session
    if tail < 0:
        raise ValueError("tail must be zero or greater")
    alive = session.process is not None and session.process.returncode is None
    status = "running" if alive else (session.terminal or "process_error")
    def compact(event: dict) -> dict:
        kind = event.get("event")
        if kind == "init":
            init = event.get("init", {})
            return {"event": "init", "conversation_id": event.get("conversation_id"),
                    "model": init.get("model"), "cwd": init.get("cwd")}
        if kind == "step_update":
            step = event.get("step_update", {})
            out = {"event": kind, "step_type": step.get("step_type"),
                   "state": step.get("state"), "text_delta": step.get("text_delta", "")}
            if step.get("usage"):
                out["usage"] = step["usage"]
            return out
        if kind == "result":
            result = event.get("result", {})
            return {"event": kind, "status": result.get("status"),
                    "response": result.get("response", ""), "error": result.get("error"),
                    "usage": result.get("usage")}
        return {"event": kind}

    response: dict[str, Any] = {"run_id": run_id, "conversation_id": session.conversation_id,
                                "alive": alive, "status": status}
    if tail:
        response["events"] = [compact(e) for e in session.events[-tail:]]
        response["diagnostics"] = session.diagnostics[-tail:]
    return response


async def agy_wait(run_id: str, timeout_seconds: float = 300) -> dict:
    """Long-poll until completion, keeping intermediate stream events off the tool response."""
    if not 0 < timeout_seconds <= 300:
        raise ValueError("timeout_seconds must be greater than zero and at most 300")
    session = sessions.get(run_id) or _load_session(run_id)
    sessions[run_id] = session
    if session.terminal is not None:
        session.done.set()
    try:
        await asyncio.wait_for(session.done.wait(), timeout=timeout_seconds)
    except TimeoutError:
        return {"run_id": run_id, "status": "timeout"}

    result = next((event.get("result", {}) for event in reversed(session.events)
                   if event.get("event") == "result"), None)
    if result is None:
        return {"run_id": run_id, "status": session.terminal or "process_error",
                "diagnostics": session.diagnostics[-1:]}
    return {"run_id": run_id, "status": result.get("status", "completed"),
            "response": result.get("response", ""), "error": result.get("error"),
            "usage": result.get("usage")}


async def agy_interrupt(run_id: str, force: bool = False) -> dict:
    """Interrupt urgently; the saved conversation ID can be continued later."""
    session = sessions.get(run_id) or _load_session(run_id)
    if session.process is None or session.process.returncode is not None:
        raise ValueError("scout process is not running")
    session.process.send_signal(signal.SIGKILL if force else signal.SIGTERM)
    await session.process.wait()
    return {"run_id": run_id, "conversation_id": session.conversation_id,
            "status": "interrupted", "signal": "SIGKILL" if force else "SIGTERM"}


async def agy_continue(run_id: str, prompt: str) -> dict:
    """Start a fresh agy process on the saved conversation after interruption."""
    old = sessions.get(run_id) or _load_session(run_id)
    if not old.conversation_id:
        raise ValueError("conversation_id is not known yet")
    process = await asyncio.create_subprocess_exec(
        AGY, "--conversation", old.conversation_id, "--model", "gemini-3.8-flash-high",
        "--effort", "high", "--output-format", "stream-json", "--input-format", "stream-json",
        "--dangerously-skip-permissions", cwd=str(ROOT), stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    assert process.stdin is not None and process.stdout is not None
    old.process = process
    old.input_file = process.stdin
    old.terminal = None
    old.done = asyncio.Event()
    asyncio.create_task(_reader(old, process))
    asyncio.create_task(_stderr_reader(old, process))
    await _send(old, prompt)
    return {"run_id": run_id, "conversation_id": old.conversation_id, "status": "continued"}


async def dispatch(name: str, args: dict[str, Any]) -> dict[str, Any]:
    if name == "agy_scout":
        result = await agy_scout(**args)
    elif name == "agy_followup":
        result = await agy_followup(**args)
    elif name == "agy_status":
        result = await agy_status(**args)
    elif name == "agy_wait":
        result = await agy_wait(**args)
    elif name == "agy_interrupt":
        result = await agy_interrupt(**args)
    elif name == "agy_continue":
        result = await agy_continue(**args)
    else:
        raise ValueError(f"unknown tool: {name}")
    result["codex_5h"] = await _codex_5h_usage()
    return result


async def serve() -> None:
    while line := await asyncio.to_thread(sys.stdin.buffer.readline):
        try:
            request = json.loads(line)
            method = request.get("method")
            if method == "initialize":
                result = {"protocolVersion": request["params"].get("protocolVersion", "2024-11-05"), "capabilities": {"tools": {}}, "serverInfo": {"name": "agy-scout", "version": "0.1.0"}}
            elif method == "notifications/initialized":
                continue
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                result = {"content": [{"type": "text", "text": json.dumps(await dispatch(request["params"]["name"], request["params"].get("arguments", {})), ensure_ascii=False)}]}
            else:
                result = {}
            if "id" in request:
                print(json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": result}), flush=True)
        except Exception as exc:
            if "id" in locals().get("request", {}):
                print(json.dumps({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -32000, "message": str(exc)}}), flush=True)


def main() -> None:
    asyncio.run(serve())


if __name__ == "__main__":
    main()
