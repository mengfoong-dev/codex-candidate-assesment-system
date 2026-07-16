"""Simulation Engine (brief 02): the candidate-facing AI assistant. One Anthropic client, a
small tool loop over the Virtual Workspace, SSE out, events in. No agent framework.

Provider seam (for the team lead / test authors): the SDK call is wrapped behind the
`SimulationLLM` protocol below. `get_llm()` is the module-level factory that
`stream_candidate_message` calls to obtain it — tests monkeypatch
`src.simulation.service.get_llm` to return a `FakeLLM` (see tests/test_simulation.py) so no
real network call is ever made in the test suite. `AnthropicLLM` is the default, real
implementation.
"""
import json
import os
from dataclasses import dataclass
from typing import AsyncIterator, Protocol
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from src.config import get_settings
from src.database import AsyncSessionLocal
from src.event_log import append_event, load_events
from src.registry import Scenario, get_scenario
from src.schemas import (
    AiPromptSubmittedPayload,
    AiResponseReceivedPayload,
    TechnicalErrorPayload,
    ToolInvokedPayload,
    TokenUsage,
)
from src.simulation import tools as workspace_tools

# Tool-loop budget (brief 02). No `sim_max_tool_calls` field exists on the frozen Settings —
# read straight from the env var the brief names instead of touching foundation config.
MAX_TOOL_CALLS = int(os.getenv("SIM_MAX_TOOL_CALLS", "8"))


# --- provider-agnostic chunk types -------------------------------------------------------


@dataclass
class TokenChunk:
    text: str


@dataclass
class ToolCallChunk:
    id: str
    name: str
    input: dict


@dataclass
class TurnDone:
    """Terminal chunk of one provider call (one round trip to the model)."""

    stop_reason: str
    usage: TokenUsage
    tool_calls: list[ToolCallChunk]
    raw_content: object  # echoed back verbatim as the assistant turn in the next call's `messages`


class SimulationLLM(Protocol):
    def stream_turn(
        self, *, system: str, messages: list[dict], tools: list[dict]
    ) -> AsyncIterator["TokenChunk | TurnDone"]:
        """Yield TokenChunk events as text streams in, then exactly one TurnDone at the end of
        this provider call. One call = one round trip; the tool loop below may invoke this
        several times per candidate message (model asks for a tool -> we return the result ->
        it continues)."""
        ...


class AnthropicLLM:
    """Real provider: the async Anthropic SDK. See the `claude-api` skill for the streaming +
    tool-use shapes this mirrors (`client.messages.stream()` + `text_stream`, then
    `get_final_message()` for the accumulated content/usage).

    Deliberately does NOT pass `temperature` — see the model-config gap noted in the PR/
    handoff report: Claude Sonnet 5 rejects non-default sampling parameters with a 400, so
    `settings.sim_temperature` (0.2) cannot actually be sent to this model.
    """

    def __init__(self, *, api_key: str, model: str, max_tokens: int):
        import anthropic

        self._client = anthropic.AsyncAnthropic(api_key=api_key)
        self._model = model
        self._max_tokens = max_tokens

    async def stream_turn(self, *, system: str, messages: list[dict], tools: list[dict]):
        async with self._client.messages.stream(
            model=self._model,
            max_tokens=self._max_tokens,
            system=system,
            tools=tools,
            messages=messages,
        ) as stream:
            async for text in stream.text_stream:
                yield TokenChunk(text=text)
            final = await stream.get_final_message()

        tool_calls = [
            ToolCallChunk(id=b.id, name=b.name, input=b.input) for b in final.content if b.type == "tool_use"
        ]
        yield TurnDone(
            stop_reason=final.stop_reason,
            usage=TokenUsage(input_tokens=final.usage.input_tokens, output_tokens=final.usage.output_tokens),
            tool_calls=tool_calls,
            raw_content=final.content,
        )


def _check_model_configured(model: str) -> None:
    """Lightweight model/health check (Codex MEDIUM finding: no hard-coded model constant —
    the model is already config in `settings.sim_model`; this just validates that config
    before spending a real API call on it)."""
    if not model or not model.startswith("claude-"):
        raise ValueError(f"sim_model is not a recognizable Anthropic model id: {model!r}")


def get_llm() -> "SimulationLLM | None":
    """Provider factory — the injectable seam. Returns None when no API key is configured
    (outage path, handled by the caller). Tests monkeypatch this function to return a
    FakeLLM instead of hitting the network."""
    settings = get_settings()
    if not settings.anthropic_api_key:
        return None
    _check_model_configured(settings.sim_model)
    return AnthropicLLM(api_key=settings.anthropic_api_key, model=settings.sim_model, max_tokens=settings.sim_max_tokens)


# --- SSE + prompt assembly helpers -------------------------------------------------------


def _sse(event: str, data: dict) -> bytes:
    return f"event: {event}\ndata: {json.dumps(data)}\n\n".encode("utf-8")


def _build_system_prompt(scenario: Scenario) -> str:
    """Candidate-safe system prompt (assessment integrity, brief 02/D002): only the public
    scenario view goes in — `candidate_safe_view()` already strips `scoring`,
    `results_by_remediation`, etc., and we only read `title`/`brief` off it, so hidden keys
    can never leak even if the redaction function's key list changes."""
    safe = scenario.candidate_safe_view()
    return (
        "You are a general-purpose engineering copilot working inside the candidate's "
        "workspace for this incident investigation. Help exactly as any real AI assistant "
        "would with the same evidence: answer questions, reason about whatever the candidate "
        "pastes or asks, and use the workspace tools when useful. Do not introduce facts "
        "beyond what the candidate has shared with you or what is in the brief below.\n\n"
        f"Incident: {safe['title']}\n{safe['brief']}\n\n"
        "You can inspect and edit the candidate's Virtual Workspace with the list_files, "
        "read_file, and write_file tools. Nothing you write ever executes."
    )


async def _build_message_history(db: AsyncSession, session_id: str) -> list[dict]:
    """Chat history derived from prior `ai_prompt_submitted`/`ai_response_received` events, in
    sequence order (brief 02). `ai_response_received.payload.text` is a non-modeled extension
    we add ourselves so a later turn can reconstruct the assistant's side of the conversation
    — see the reported gap in the handoff notes (AiResponseReceivedPayload has no text field)."""
    events = await load_events(db, session_id)
    messages: list[dict] = []
    for e in events:
        if e["event_type"] == "ai_prompt_submitted":
            messages.append({"role": "user", "content": e["payload"]["prompt"]})
        elif e["event_type"] == "ai_response_received":
            text = e["payload"].get("text", "")
            if text:
                messages.append({"role": "assistant", "content": text})
    return messages


async def _invoke_tool(db: AsyncSession, session_id: str, call: ToolCallChunk, files_written: list[str]) -> str:
    if call.name == "list_files":
        return await workspace_tools.list_files(db, session_id)
    if call.name == "read_file":
        return await workspace_tools.read_file(db, session_id, call.input.get("path", ""))
    if call.name == "write_file":
        await workspace_tools.write_file(db, session_id, call.input["path"], call.input["content"])
        files_written.append(call.input["path"])
        return f"Wrote {call.input['path']}."
    return f"Unknown tool: {call.name}"


# --- the engine ---------------------------------------------------------------------------


async def stream_candidate_message(
    *, session_id: str, scenario_id: str, scenario_version: str, content: str
) -> AsyncIterator[bytes]:
    """The SSE generator for POST /sessions/{id}/messages. Opens its OWN AsyncSessionLocal()
    (the request-scoped session from the router closes too early for a streaming response)."""
    turn_id = str(uuid4())

    async with AsyncSessionLocal() as db:
        # History is built from events recorded before this turn — this turn's own
        # ai_prompt_submitted is appended next, so building history first avoids double-
        # counting the current prompt.
        history = await _build_message_history(db, session_id)

        await append_event(
            db,
            session_id=session_id,
            scenario_id=scenario_id,
            scenario_version=scenario_version,
            event_type="ai_prompt_submitted",
            actor="candidate",
            payload=AiPromptSubmittedPayload(turn_id=turn_id, prompt=content).model_dump(),
        )

        total_input = 0
        total_output = 0
        files_written: list[str] = []
        response_text_parts: list[str] = []

        try:
            llm = get_llm()
            if llm is None:
                raise RuntimeError("ANTHROPIC_API_KEY is not configured")

            scenario = get_scenario(scenario_id, scenario_version)
            system_prompt = _build_system_prompt(scenario)
            messages = history + [{"role": "user", "content": content}]

            tool_call_seq = 0

            while True:
                assistant_content = None
                stop_reason = None
                tool_calls: list[ToolCallChunk] = []

                async for chunk in llm.stream_turn(system=system_prompt, messages=messages, tools=workspace_tools.TOOL_SCHEMAS):
                    if isinstance(chunk, TokenChunk):
                        yield _sse("token", {"text": chunk.text})
                        response_text_parts.append(chunk.text)
                    else:
                        total_input += chunk.usage.input_tokens
                        total_output += chunk.usage.output_tokens
                        assistant_content = chunk.raw_content
                        stop_reason = chunk.stop_reason
                        tool_calls = chunk.tool_calls

                messages.append({"role": "assistant", "content": assistant_content})

                if stop_reason != "tool_use" or not tool_calls:
                    break

                tool_results = []
                for call in tool_calls:
                    tool_call_seq += 1
                    if tool_call_seq > MAX_TOOL_CALLS:
                        # Budget exhausted (brief 02): refuse the call, tell the model to
                        # conclude — no tool_invoked event, no SSE, nothing actually runs.
                        tool_results.append(
                            {
                                "type": "tool_result",
                                "tool_use_id": call.id,
                                "content": "Tool call budget exhausted for this message — conclude your response now.",
                                "is_error": True,
                            }
                        )
                        continue

                    result_text = await _invoke_tool(db, session_id, call, files_written)
                    await append_event(
                        db,
                        session_id=session_id,
                        scenario_id=scenario_id,
                        scenario_version=scenario_version,
                        event_type="tool_invoked",
                        actor="scripted_assistant",
                        payload=ToolInvokedPayload(
                            turn_id=turn_id, tool=call.name, path=call.input.get("path"), outcome="ok"
                        ).model_dump(),
                    )
                    yield _sse("tool_use", {"tool": call.name, "path": call.input.get("path", "")})
                    if call.name == "write_file":
                        yield _sse("file_updated", {"path": call.input["path"], "source": "ai"})
                    tool_results.append({"type": "tool_result", "tool_use_id": call.id, "content": result_text})

                messages.append({"role": "user", "content": tool_results})

        except Exception as exc:  # noqa: BLE001 — outage handling is intentionally broad (brief 02)
            message = f"Simulation Engine could not reach the model: {exc}"
            yield _sse("error", {"code": "llm_unavailable", "message": message})
            await append_event(
                db,
                session_id=session_id,
                scenario_id=scenario_id,
                scenario_version=scenario_version,
                event_type="technical_error",
                actor="system",
                payload=TechnicalErrorPayload(
                    source="simulation",
                    message=message,
                    excluded_criterion_ids=["independence_checked", "unverified_ai_acceptance"],
                ).model_dump(),
            )
            return

        response_id = f"{turn_id}:resp"
        payload = AiResponseReceivedPayload(
            turn_id=turn_id,
            response_id=response_id,
            model_label=get_settings().sim_model,
            status="ok",
            usage=TokenUsage(input_tokens=total_input, output_tokens=total_output),
        ).model_dump()
        # Non-modeled extensions (reported gap — AiResponseReceivedPayload has neither field):
        # files_written per brief 02, text so the next turn can reconstruct this one in history.
        payload["files_written"] = files_written
        payload["text"] = "".join(response_text_parts)

        await append_event(
            db,
            session_id=session_id,
            scenario_id=scenario_id,
            scenario_version=scenario_version,
            event_type="ai_response_received",
            actor="scripted_assistant",
            payload=payload,
        )

        yield _sse(
            "done",
            {"response_id": response_id, "usage": {"input_tokens": total_input, "output_tokens": total_output}},
        )
