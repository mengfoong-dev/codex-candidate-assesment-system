"""Tests for the Simulation Engine (SSE chat + Virtual Workspace tools) — brief 02.

Provider seam: `src.simulation.service.get_llm` is monkeypatched in every test to return a
FakeLLM (scripted turns) or FailingLLM (raises immediately) — no real network call is ever
made here, per the HARD RULE against calling a real LLM API in tests.

This file runs its OWN minimal FastAPI app (just the simulation router) instead of
`src.main.create_app`. `main.py` imports all six domain routers, but only `src.simulation`
exists at this point in the parallel build (sessions/events/workspace/scenarios/evaluation
are other implementers' work) — the lead runs the full app import at integration once every
domain lands. Building the schema and inserting a `Session` row directly (via the foundation
`Session`/`SessionFile` models) sidesteps the not-yet-built sessions domain the same way.
"""
import json
from types import SimpleNamespace

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from src.database import AsyncSessionLocal, Base, engine
from src.event_log import load_events, now_iso
from src.exceptions import register_exception_handlers
from src.models import Session as SessionRow, SessionFile
from src.schemas import TokenUsage
from src.simulation import tools as workspace_tools
from src.simulation import service
from src.simulation.router import router as simulation_router
from src.simulation.service import ToolCallChunk, TokenChunk, TurnDone, _check_model_configured


class FakeLLM:
    """Test double for SimulationLLM — scripted provider calls, no network.

    `turns` is a list of "provider calls"; each call is itself a list of TokenChunk/TurnDone
    objects to yield in order from one `stream_turn` invocation. One list entry is popped per
    loop iteration in the tool loop (i.e. once per round trip to "the model").
    """

    def __init__(self, turns: list[list]):
        self._turns = list(turns)
        self.call_count = 0

    async def stream_turn(self, *, system, messages, tools):
        self.call_count += 1
        for chunk in self._turns.pop(0):
            yield chunk


class FailingLLM:
    """Simulates a provider outage — raises before yielding anything."""

    async def stream_turn(self, *, system, messages, tools):
        raise RuntimeError("simulated provider outage")
        yield  # pragma: no cover — unreachable; makes this an async generator function


@pytest_asyncio.fixture
async def sim_app():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    app = FastAPI()
    register_exception_handlers(app)  # so AppError(404/409) renders the standard error envelope
    app.include_router(simulation_router, prefix="/api")
    return app


@pytest_asyncio.fixture
async def sim_client(sim_app):
    transport = ASGITransport(app=sim_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest_asyncio.fixture
async def active_session():
    """Insert a Session row directly (bypasses the sessions domain, which doesn't exist yet)."""
    session_id = "sim-test-session-active"
    async with AsyncSessionLocal() as db:
        db.add(
            SessionRow(
                id=session_id,
                scenario_id="homepage_latency",
                scenario_version="1.0.0",
                display_name="Test Candidate",
                status="active",
                started_at=now_iso(),
            )
        )
        await db.commit()
    return session_id


def _parse_sse(raw: str) -> list[tuple[str, dict]]:
    """Split a raw SSE body (`event: X\\ndata: Y\\n\\n` repeated) into (event, data) pairs."""
    events = []
    for block in raw.strip().split("\n\n"):
        if not block.strip():
            continue
        lines = block.strip().split("\n")
        event = lines[0].removeprefix("event: ")
        data = json.loads(lines[1].removeprefix("data: "))
        events.append((event, data))
    return events


# --- happy path: tokens + one write_file tool call + usage integers ----------------------


@pytest.mark.asyncio
async def test_happy_path_write_file_and_usage(sim_client, active_session, monkeypatch):
    fake = FakeLLM(
        [
            [
                TokenChunk(text="Looking at the orchestrator, "),
                TokenChunk(text="I'll parallelize the independent calls."),
                TurnDone(
                    stop_reason="tool_use",
                    usage=TokenUsage(input_tokens=100, output_tokens=40),
                    tool_calls=[
                        ToolCallChunk(
                            id="call_1",
                            name="write_file",
                            input={"path": "src/homepage_orchestrator.ts", "content": "// parallelized\n"},
                        )
                    ],
                    raw_content=[{"type": "text", "text": "..."}],
                ),
            ],
            [
                TokenChunk(text="Done — the calls now run concurrently."),
                TurnDone(
                    stop_reason="end_turn",
                    usage=TokenUsage(input_tokens=50, output_tokens=20),
                    tool_calls=[],
                    raw_content=[{"type": "text", "text": "Done"}],
                ),
            ],
        ]
    )
    monkeypatch.setattr(service, "get_llm", lambda: fake)

    resp = await sim_client.post(
        f"/api/sessions/{active_session}/messages", json={"content": "Fix the latency"}
    )
    assert resp.status_code == 200
    events = _parse_sse(resp.text)
    types = [e for e, _ in events]

    assert "token" in types
    assert "tool_use" in types
    assert "file_updated" in types
    assert types[-1] == "done"

    done_payload = events[-1][1]
    assert done_payload["usage"]["input_tokens"] == 150
    assert done_payload["usage"]["output_tokens"] == 60

    async with AsyncSessionLocal() as db:
        f = await db.get(SessionFile, (active_session, "src/homepage_orchestrator.ts"))
        assert f is not None
        assert f.source == "ai"
        assert f.content == "// parallelized\n"

        stored = await load_events(db, active_session)
        prompt_events = [e for e in stored if e["event_type"] == "ai_prompt_submitted"]
        response_events = [e for e in stored if e["event_type"] == "ai_response_received"]
        assert len(prompt_events) == 1
        assert len(response_events) == 1
        # Invariant: SSE done.usage MUST equal the persisted ai_response_received usage total.
        assert response_events[0]["payload"]["usage"]["input_tokens"] == done_payload["usage"]["input_tokens"]
        assert response_events[0]["payload"]["usage"]["output_tokens"] == done_payload["usage"]["output_tokens"]
        assert response_events[0]["payload"]["turn_id"] == prompt_events[0]["payload"]["turn_id"]


# --- multi-call loop: 2 provider calls, 1 parallel-tool_use turn -> exactly ONE ai_response_received ---


@pytest.mark.asyncio
async def test_multi_call_loop_single_response_received_event(sim_client, active_session, monkeypatch):
    fake = FakeLLM(
        [
            [
                TurnDone(
                    stop_reason="tool_use",
                    usage=TokenUsage(input_tokens=80, output_tokens=30),
                    tool_calls=[
                        ToolCallChunk(id="call_1", name="list_files", input={}),
                        ToolCallChunk(
                            id="call_2", name="read_file", input={"path": "src/homepage_orchestrator.ts"}
                        ),
                    ],
                    raw_content=[{"type": "text", "text": "checking files"}],
                ),
            ],
            [
                TurnDone(
                    stop_reason="end_turn",
                    usage=TokenUsage(input_tokens=40, output_tokens=15),
                    tool_calls=[],
                    raw_content=[{"type": "text", "text": "done"}],
                ),
            ],
        ]
    )
    monkeypatch.setattr(service, "get_llm", lambda: fake)

    resp = await sim_client.post(
        f"/api/sessions/{active_session}/messages", json={"content": "What's in the workspace?"}
    )
    assert resp.status_code == 200
    events = _parse_sse(resp.text)

    tool_use_events = [e for e in events if e[0] == "tool_use"]
    assert len(tool_use_events) == 2
    assert fake.call_count == 2  # exactly 2 provider round trips

    async with AsyncSessionLocal() as db:
        stored = await load_events(db, active_session)
        response_events = [e for e in stored if e["event_type"] == "ai_response_received"]
        tool_invoked_events = [e for e in stored if e["event_type"] == "tool_invoked"]

        assert len(response_events) == 1
        assert len(tool_invoked_events) == 2
        assert response_events[0]["payload"]["usage"]["input_tokens"] == 120
        assert response_events[0]["payload"]["usage"]["output_tokens"] == 45

        turn_ids = {
            tool_invoked_events[0]["payload"]["turn_id"],
            tool_invoked_events[1]["payload"]["turn_id"],
            response_events[0]["payload"]["turn_id"],
        }
        assert len(turn_ids) == 1  # ai_prompt_submitted/tool_invoked*/ai_response_received share one turn_id


# --- tool-cap: 9th call refused, response still concludes ---------------------------------


@pytest.mark.asyncio
async def test_tool_cap_refuses_ninth_call_but_still_concludes(sim_client, active_session, monkeypatch):
    turns = []
    for i in range(9):
        turns.append(
            [
                TurnDone(
                    stop_reason="tool_use",
                    usage=TokenUsage(input_tokens=10, output_tokens=5),
                    tool_calls=[ToolCallChunk(id=f"call_{i}", name="list_files", input={})],
                    raw_content=[{"type": "text", "text": f"turn {i}"}],
                )
            ]
        )
    turns.append(
        [
            TurnDone(
                stop_reason="end_turn",
                usage=TokenUsage(input_tokens=10, output_tokens=5),
                tool_calls=[],
                raw_content=[{"type": "text", "text": "concluding"}],
            )
        ]
    )
    fake = FakeLLM(turns)
    monkeypatch.setattr(service, "get_llm", lambda: fake)

    resp = await sim_client.post(
        f"/api/sessions/{active_session}/messages", json={"content": "keep checking files"}
    )
    assert resp.status_code == 200
    events = _parse_sse(resp.text)
    assert events[-1][0] == "done"

    tool_use_events = [e for e in events if e[0] == "tool_use"]
    assert len(tool_use_events) == 8  # 9th refused before ever being invoked

    async with AsyncSessionLocal() as db:
        stored = await load_events(db, active_session)
        tool_invoked_events = [e for e in stored if e["event_type"] == "tool_invoked"]
        response_events = [e for e in stored if e["event_type"] == "ai_response_received"]
        assert len(tool_invoked_events) == 8
        assert len(response_events) == 1  # still concludes with exactly one response event


# --- outage: provider raises -> error SSE + technical_error event -------------------------


@pytest.mark.asyncio
async def test_outage_emits_error_and_technical_error_event(sim_client, active_session, monkeypatch):
    monkeypatch.setattr(service, "get_llm", lambda: FailingLLM())

    resp = await sim_client.post(f"/api/sessions/{active_session}/messages", json={"content": "help"})
    assert resp.status_code == 200
    events = _parse_sse(resp.text)
    assert events[-1][0] == "error"
    assert events[-1][1]["code"] == "llm_unavailable"

    async with AsyncSessionLocal() as db:
        stored = await load_events(db, active_session)
        tech_errors = [e for e in stored if e["event_type"] == "technical_error"]
        assert len(tech_errors) == 1
        assert tech_errors[0]["payload"]["source"] == "simulation"
        assert set(tech_errors[0]["payload"]["excluded_criterion_ids"]) == {
            "independence_checked",
            "unverified_ai_acceptance",
        }
        # No ai_response_received on an outage — grading must not see a fabricated success.
        assert not [e for e in stored if e["event_type"] == "ai_response_received"]


@pytest.mark.asyncio
async def test_missing_api_key_emits_error(sim_client, active_session, monkeypatch):
    """Same outage path when the key is simply absent (get_llm() returns None)."""
    monkeypatch.setattr(service, "get_llm", lambda: None)

    resp = await sim_client.post(f"/api/sessions/{active_session}/messages", json={"content": "help"})
    events = _parse_sse(resp.text)
    assert events[-1][0] == "error"
    assert events[-1][1]["code"] == "llm_unavailable"


# --- 409 on a submitted session: no stream started ----------------------------------------


@pytest.mark.asyncio
async def test_submitted_session_returns_409_and_does_not_stream(sim_client):
    session_id = "sim-test-session-submitted"
    async with AsyncSessionLocal() as db:
        db.add(
            SessionRow(
                id=session_id,
                scenario_id="homepage_latency",
                scenario_version="1.0.0",
                display_name="Test Candidate",
                status="submitted",
                started_at=now_iso(),
            )
        )
        await db.commit()

    resp = await sim_client.post(f"/api/sessions/{session_id}/messages", json={"content": "hi"})
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "session_not_active"


@pytest.mark.asyncio
async def test_unknown_session_returns_404(sim_client):
    resp = await sim_client.post("/api/sessions/does-not-exist/messages", json={"content": "hi"})
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "session_not_found"


# --- redaction: system prompt provably excludes hidden scenario keys ----------------------


def test_system_prompt_excludes_hidden_scenario_keys():
    from src.registry import get_scenario
    from src.simulation.service import _build_system_prompt

    scenario = get_scenario("homepage_latency", "1.0.0")
    prompt = _build_system_prompt(scenario)

    assert "results_by_remediation" not in prompt
    assert "configured_points" not in prompt
    assert "scoring" not in prompt
    assert "root_cause" not in prompt


# --- model/health check --------------------------------------------------------------------


def test_check_model_configured():
    with pytest.raises(ValueError):
        _check_model_configured("claude-sonnet-5")
    with pytest.raises(ValueError):
        _check_model_configured("")
    _check_model_configured("command-a-plus-05-2026")  # does not raise


class RecordingCohereClient:
    """A complete local V2 stream double; it never reaches the Cohere network."""

    def __init__(self, turns):
        self._turns = list(turns)
        self.calls = []

    def chat_stream(self, **kwargs):
        self.calls.append(kwargs)
        events = self._turns.pop(0)

        async def stream():
            for event in events:
                yield event

        return stream()


def _cohere_event(event_type, **kwargs):
    return SimpleNamespace(type=event_type, **kwargs)


def _cohere_usage(input_tokens, output_tokens):
    return SimpleNamespace(tokens=SimpleNamespace(input_tokens=input_tokens, output_tokens=output_tokens))


@pytest.mark.asyncio
async def test_cohere_adapter_reconstructs_streamed_tool_arguments_and_usage():
    """Provider adapter contract: V2 deltas become the existing neutral turn objects."""
    cohere_llm = getattr(service, "CohereLLM", None)
    assert cohere_llm is not None, "Cohere must replace the Anthropic simulation adapter"

    tool_call = SimpleNamespace(
        id="call_write", type="function", function=SimpleNamespace(name="write_file", arguments="")
    )
    client = RecordingCohereClient(
        [[
            _cohere_event(
                "content-delta",
                delta=SimpleNamespace(message=SimpleNamespace(content=SimpleNamespace(text="I can update it."))),
            ),
            _cohere_event(
                "tool-call-start",
                index=0,
                delta=SimpleNamespace(message=SimpleNamespace(tool_calls=tool_call)),
            ),
            _cohere_event(
                "tool-call-delta",
                index=0,
                delta=SimpleNamespace(
                    message=SimpleNamespace(tool_calls=SimpleNamespace(function=SimpleNamespace(arguments='{"path":"src/')))
                ),
            ),
            _cohere_event(
                "tool-call-delta",
                index=0,
                delta=SimpleNamespace(
                    message=SimpleNamespace(
                        tool_calls=SimpleNamespace(function=SimpleNamespace(arguments='a.ts","content":"// fixed"}'))
                    )
                ),
            ),
            _cohere_event(
                "message-end",
                delta=SimpleNamespace(
                    message=SimpleNamespace(finish_reason="TOOL_CALL", usage=_cohere_usage(101, 23))
                ),
            ),
        ]]
    )
    llm = cohere_llm(
        api_key="fake-key", model="command-a-plus-05-2026", max_tokens=128, client=client
    )

    chunks = [
        chunk
        async for chunk in llm.stream_turn(
            system="system",
            messages=[{"role": "user", "content": "help"}],
            tools=workspace_tools.COHERE_TOOL_SCHEMAS,
        )
    ]

    assert [chunk.text for chunk in chunks if isinstance(chunk, TokenChunk)] == ["I can update it."]
    done = chunks[-1]
    assert isinstance(done, TurnDone)
    assert done.stop_reason == "tool_use"
    assert done.usage == TokenUsage(input_tokens=101, output_tokens=23)
    assert done.tool_calls == [
        ToolCallChunk(
            id="call_write",
            name="write_file",
            input={"path": "src/a.ts", "content": "// fixed"},
        )
    ]
    assert done.raw_content["role"] == "assistant"
    assert done.raw_content["tool_calls"][0]["function"]["arguments"] == '{"path":"src/a.ts","content":"// fixed"}'
    assert client.calls[0]["model"] == "command-a-plus-05-2026"
    assert client.calls[0]["tools"] == workspace_tools.COHERE_TOOL_SCHEMAS
    assert client.calls[0]["strict_tools"] is True


@pytest.mark.asyncio
async def test_cohere_tool_result_round_trip_uses_v2_tool_messages(sim_client, active_session, monkeypatch):
    """The second Cohere request must contain the assistant call and matching tool document."""
    cohere_llm = getattr(service, "CohereLLM", None)
    assert cohere_llm is not None, "Cohere must replace the Anthropic simulation adapter"

    tool_call = SimpleNamespace(
        id="call_list", type="function", function=SimpleNamespace(name="list_files", arguments="")
    )
    client = RecordingCohereClient(
        [
            [
                _cohere_event(
                    "tool-call-start",
                    index=0,
                    delta=SimpleNamespace(message=SimpleNamespace(tool_calls=tool_call)),
                ),
                _cohere_event(
                    "tool-call-delta",
                    index=0,
                    delta=SimpleNamespace(
                        message=SimpleNamespace(tool_calls=SimpleNamespace(function=SimpleNamespace(arguments="{}")))
                    ),
                ),
                _cohere_event(
                    "message-end",
                    delta=SimpleNamespace(
                        message=SimpleNamespace(finish_reason="TOOL_CALL", usage=_cohere_usage(30, 8))
                    ),
                ),
            ],
            [
                _cohere_event(
                    "content-delta",
                    delta=SimpleNamespace(message=SimpleNamespace(content=SimpleNamespace(text="Workspace checked."))),
                ),
                _cohere_event(
                    "message-end",
                    delta=SimpleNamespace(
                        message=SimpleNamespace(finish_reason="COMPLETE", usage=_cohere_usage(25, 9))
                    ),
                ),
            ],
        ]
    )
    llm = cohere_llm(
        api_key="fake-key", model="command-a-plus-05-2026", max_tokens=128, client=client
    )
    monkeypatch.setattr(service, "get_llm", lambda: llm)

    resp = await sim_client.post(f"/api/sessions/{active_session}/messages", json={"content": "List files"})

    assert resp.status_code == 200
    assert _parse_sse(resp.text)[-1][0] == "done"
    assert len(client.calls) == 2
    follow_up_messages = client.calls[1]["messages"]
    assert follow_up_messages[-2]["role"] == "assistant"
    assert follow_up_messages[-2]["tool_calls"][0]["id"] == "call_list"
    assert follow_up_messages[-1]["role"] == "tool"
    assert follow_up_messages[-1]["tool_call_id"] == "call_list"
    assert follow_up_messages[-1]["content"][0]["type"] == "document"
    assert follow_up_messages[-1]["content"][0]["document"]["data"] == {
        "result": "No files in the workspace.",
        "is_error": False,
    }
