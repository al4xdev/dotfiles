import asyncio
from datetime import UTC, datetime, timedelta

from agy_mcp import server


def setup_function() -> None:
    server.sessions.clear()


def test_status_omits_events_unless_requested(tmp_path) -> None:
    session = server.Session("run", None, None, tmp_path / "run.jsonl")
    session.events.append({"event": "step_update", "step_update": {"state": "ACTIVE"}})
    server.sessions["run"] = session

    assert asyncio.run(server.agy_status("run")) == {
        "run_id": "run", "conversation_id": None, "alive": False, "status": "process_error"
    }
    assert asyncio.run(server.agy_status("run", tail=1))["events"] == [
        {"event": "step_update", "step_type": None, "state": "ACTIVE", "text_delta": ""}
    ]


def test_wait_returns_result_without_stream_events(tmp_path) -> None:
    session = server.Session("run", None, None, tmp_path / "run.jsonl")
    session.events.extend([
        {"event": "step_update", "step_update": {"state": "ACTIVE", "text_delta": "hidden"}},
        {"event": "result", "result": {"status": "SUCCESS", "response": "answer", "usage": {"total_tokens": 3}}},
    ])
    session.terminal = "SUCCESS"
    session.done.set()
    server.sessions["run"] = session

    assert asyncio.run(server.agy_wait("run", timeout_seconds=1)) == {
        "run_id": "run", "status": "SUCCESS", "response": "answer", "error": None,
        "usage": {"total_tokens": 3},
    }


def test_wait_times_out(tmp_path) -> None:
    server.sessions["run"] = server.Session("run", None, None, tmp_path / "run.jsonl")

    assert asyncio.run(server.agy_wait("run", timeout_seconds=0.01)) == {
        "run_id": "run", "status": "timeout"
    }


def test_five_hour_window_uses_codex_bucket() -> None:
    snapshot = {
        "rateLimitsByLimitId": {
            "other": {"limitId": "other", "primary": {"usedPercent": 99, "windowDurationMins": 300, "resetsAt": 100}},
            "codex": {"limitId": "codex", "primary": {"usedPercent": 80, "windowDurationMins": 300, "resetsAt": 1790220073}},
        },
    }
    assert server._five_hour_window(snapshot) == {
        "remaining_percent": 20,
        "resets_at": "2026-09-24T03:21:13+00:00",
    }


def test_five_hour_window_recommends_wait_only_before_reset() -> None:
    reset = int((datetime.now(UTC) + timedelta(hours=1)).timestamp())
    snapshot = {"rateLimits": {"limitId": "codex", "primary": {
        "usedPercent": 95, "windowDurationMins": 300, "resetsAt": reset,
    }}}
    usage = server._five_hour_window(snapshot)
    assert usage is not None
    assert usage["remaining_percent"] == 5
    assert "aguarde" in usage["recommendation"]

    snapshot["rateLimits"]["primary"]["resetsAt"] = 1
    expired = server._five_hour_window(snapshot)
    assert expired is not None
    assert "recommendation" not in expired


def test_five_hour_window_missing_or_other_duration() -> None:
    assert server._five_hour_window({}) is None
    assert server._five_hour_window({"rateLimits": {
        "limitId": "codex", "primary": {"usedPercent": 90, "windowDurationMins": 10080, "resetsAt": 1790220073},
    }}) is None


def test_dispatch_adds_usage_without_changing_result(monkeypatch, tmp_path) -> None:
    session = server.Session("run", None, None, tmp_path / "run.jsonl")
    server.sessions["run"] = session

    async def usage():
        return {"remaining_percent": 5, "resets_at": "2026-09-24T03:21:13+00:00"}

    monkeypatch.setattr(server, "_codex_5h_usage", usage)
    assert asyncio.run(server.dispatch("agy_status", {"run_id": "run"})) == {
        "run_id": "run", "conversation_id": None, "alive": False,
        "status": "process_error", "codex_5h": {
            "remaining_percent": 5, "resets_at": "2026-09-24T03:21:13+00:00",
        },
    }
