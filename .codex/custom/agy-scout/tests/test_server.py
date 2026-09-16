import asyncio

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
