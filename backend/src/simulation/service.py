"""Simulation Engine (brief 02): the candidate-facing AI assistant. One Cohere client, a
small tool loop over the Virtual Workspace, SSE out, events in. No agent framework.

Provider seam (for the team lead / test authors): the SDK call is wrapped behind the
`SimulationLLM` protocol below. `get_llm()` is the module-level factory that
`stream_candidate_message` calls to obtain it — tests monkeypatch
`src.simulation.service.get_llm` to return a `FakeLLM` (see tests/test_simulation.py) so no
real network call is ever made in the test suite. `CohereLLM` is the default, real
implementation.
"""
import inspect
import json
import logging
import os
from dataclasses import dataclass
from typing import AsyncIterator, Protocol
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from src.config import get_settings
from src.database import AsyncSessionLocal
from src.event_log import append_event, load_events
from src.exceptions import AppError
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
MAX_CANDIDATE_TURNS = 5
COHERE_STREAM_ATTEMPTS = 2
COHERE_STRICT_TOOLS = True
SAFE_MODEL_UNAVAILABLE_MESSAGE = "The coding agent is temporarily unavailable. Please retry this turn."
logger = logging.getLogger("vibeproof.simulation")


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


class RemovedProvider:
    """Inert compatibility placeholder; Cohere is the sole live simulation provider.
    tool-use shapes this mirrors (`client.messages.stream()` + `text_stream`, then
    `get_final_message()` for the accumulated content/usage).

    Deliberately does NOT pass `temperature` — see the model-config gap noted in the PR/
    handoff report: Claude Sonnet 5 rejects non-default sampling parameters with a 400, so
    `settings.sim_temperature` (0.2) cannot actually be sent to this model.
    """

    def __init__(self, *, api_key: str, model: str, max_tokens: int):
        raise RuntimeError("This removed provider cannot be used")
        self._model = model
        self._max_tokens = max_tokens

    async def stream_turn(self, *, system: str, messages: list[dict], tools: list[dict]):
        raise RuntimeError("This removed provider cannot be used")
        yield  # pragma: no cover - makes this an async generator for compatibility only


DEFAULT_COHERE_MODEL = "command-a-plus-05-2026"


def _value(value: object, *path: str, default=None):
    """Read Cohere SDK objects and plain fake-test dictionaries through one small adapter."""
    current = value
    for key in path:
        if current is None:
            return default
        current = current.get(key) if isinstance(current, dict) else getattr(current, key, None)
    return default if current is None else current


def _first(value: object) -> object | None:
    if isinstance(value, (list, tuple)):
        return value[0] if value else None
    return value


def _is_invalid_tool_generation(exc: Exception) -> bool:
    """Identify Cohere's retryable strict-tool generation failure without surfacing its body."""
    body = getattr(exc, "body", None)
    if not isinstance(body, dict):
        return False
    return str(body.get("error_type", "")).upper() == "INVALID_TOOL_GENERATION"


class CohereLLM:
    """Cohere Chat V2 streaming adapter translated into the provider-neutral simulation loop."""

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        max_tokens: int,
        temperature: float = 0.2,
        client: object | None = None,
    ):
        if client is None:
            import cohere

            client = cohere.AsyncClientV2(api_key=api_key)
        self._client = client
        self._model = model
        self._max_tokens = max_tokens
        self._temperature = temperature

    async def stream_turn(self, *, system: str, messages: list[dict], tools: list[dict]):
        request_messages = [{"role": "system", "content": system}, *messages]
        request = {
            "model": self._model,
            "messages": request_messages,
            "tools": tools,
            # Cohere receives only the required-input read/write functions. Strict mode
            # prevents malformed tool calls from reaching the provider's generation boundary;
            # application code remains the authority for all session-scoped operations.
            "strict_tools": COHERE_STRICT_TOOLS,
            "max_tokens": self._max_tokens,
            "temperature": self._temperature,
        }

        retry_with_non_strict_tools = False
        for attempt in range(COHERE_STREAM_ATTEMPTS):
            text_parts: list[str] = []
            calls: dict[int, dict[str, str]] = {}
            finish_reason = "COMPLETE"
            usage = TokenUsage(input_tokens=0, output_tokens=0)
            emitted_text = False
            try:
                attempt_request = {
                    **request,
                    "strict_tools": False if retry_with_non_strict_tools else COHERE_STRICT_TOOLS,
                }
                stream = self._client.chat_stream(**attempt_request)
                if inspect.isawaitable(stream):
                    stream = await stream

                async for event in stream:
                    event_type = _value(event, "type")
                    if event_type == "content-delta":
                        text = _value(event, "delta", "message", "content", "text", default="")
                        if text:
                            text = str(text)
                            text_parts.append(text)
                            emitted_text = True
                            yield TokenChunk(text=text)
                    elif event_type == "tool-call-start":
                        index = int(_value(event, "index", default=len(calls)))
                        tool_call = _first(_value(event, "delta", "message", "tool_calls"))
                        calls[index] = {
                            "id": str(_value(tool_call, "id", default="")),
                            "name": str(_value(tool_call, "function", "name", default="")),
                            "arguments": str(_value(tool_call, "function", "arguments", default="")),
                        }
                    elif event_type == "tool-call-delta":
                        index = int(_value(event, "index", default=len(calls) - 1))
                        call = calls.setdefault(index, {"id": "", "name": "", "arguments": ""})
                        delta_call = _first(_value(event, "delta", "message", "tool_calls"))
                        call["arguments"] += str(_value(delta_call, "function", "arguments", default=""))
                    elif event_type == "message-end":
                        finish_reason = str(_value(event, "delta", "message", "finish_reason", default="COMPLETE"))
                        usage = TokenUsage(
                            input_tokens=int(_value(event, "delta", "message", "usage", "tokens", "input_tokens", default=0)),
                            output_tokens=int(_value(event, "delta", "message", "usage", "tokens", "output_tokens", default=0)),
                        )
                break
            except Exception as exc:
                if emitted_text or attempt + 1 == COHERE_STREAM_ATTEMPTS:
                    raise
                retry_with_non_strict_tools = _is_invalid_tool_generation(exc)
                retry_mode = " with non-strict tools" if retry_with_non_strict_tools else ""
                logger.warning("Retrying Cohere stream after pre-output %s%s", type(exc).__name__, retry_mode)

        tool_calls: list[ToolCallChunk] = []
        raw_tool_calls: list[dict] = []
        for call in calls.values():
            arguments = call["arguments"] or "{}"
            parsed_arguments = json.loads(arguments)
            tool_calls.append(ToolCallChunk(id=call["id"], name=call["name"], input=parsed_arguments))
            raw_tool_calls.append(
                {
                    "id": call["id"],
                    "type": "function",
                    "function": {"name": call["name"], "arguments": arguments},
                }
            )

        raw_message: dict = {"role": "assistant"}
        if raw_tool_calls:
            # Command A+ rejects assistant tool_plan fields in a follow-up request. Echo only
            # the tool calls, then provide one serialized document for each matching call ID.
            raw_message["tool_calls"] = raw_tool_calls
        elif text_parts:
            raw_message["content"] = [{"type": "text", "text": "".join(text_parts)}]
        yield TurnDone(
            # Command A+ can return a COMPLETE finish reason alongside streamed tool-call
            # events. The calls themselves are the authoritative signal for the loop; relying
            # solely on finish_reason discarded valid read/write requests and left the UI with
            # only the model's textual tool plan.
            stop_reason="tool_use" if tool_calls else "end_turn",
            usage=usage,
            tool_calls=tool_calls,
            raw_content=raw_message,
        )


def _check_model_configured(model: str) -> None:
    """Lightweight model/health check (Codex MEDIUM finding: no hard-coded model constant —
    the model is already config in `settings.cohere_model`; this just validates that config
    before spending a real API call on it)."""
    if model != DEFAULT_COHERE_MODEL:
        raise ValueError(f"cohere_model must be {DEFAULT_COHERE_MODEL!r}, got {model!r}")


def get_llm() -> "SimulationLLM | None":
    """Provider factory — the injectable seam. Returns None when no API key is configured
    (outage path, handled by the caller). Tests monkeypatch this function to return a
    FakeLLM instead of hitting the network."""
    settings = get_settings()
    if not settings.cohere_api_key:
        return None
    _check_model_configured(settings.cohere_model)
    return CohereLLM(
        api_key=settings.cohere_api_key,
        model=settings.cohere_model,
        max_tokens=settings.sim_max_tokens,
        temperature=settings.sim_temperature,
    )


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
        "The frontend displays the sandbox file inventory from its workspace API. You can inspect "
        "or edit a known sandbox file with the read_file and write_file tools. If the candidate "
        "asks you to read or edit a known workspace file, invoke the appropriate workspace tool "
        "before explaining the result. Do not claim a workspace action without a matching tool "
        "call. You cannot access source-control history, shell commands, or files outside the "
        "displayed sandbox inventory; say so plainly instead of attempting an invented path. "
        "Nothing you write ever executes."
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


def _assistant_message(raw_content: object) -> dict:
    """Keep fake-provider compatibility while passing Cohere's assistant call back verbatim."""
    if isinstance(raw_content, dict) and raw_content.get("role") == "assistant":
        return raw_content
    return {"role": "assistant", "content": raw_content}


def _cohere_tool_result(legacy_result: dict) -> dict:
    """Translate the loop's provider-neutral result into Cohere's V2 tool-message envelope."""
    tool_call_id = str(legacy_result["tool_use_id"]).strip()
    if not tool_call_id:
        raise ValueError("Cohere tool result is missing a tool call ID")
    payload = {
        "result": legacy_result["content"],
        "is_error": bool(legacy_result.get("is_error", False)),
    }
    return {
        "role": "tool",
        "tool_call_id": tool_call_id,
        "content": [{"type": "document", "document": {"data": json.dumps(payload)}}],
    }


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
        total_input = 0
        total_output = 0
        files_written: list[str] = []
        response_text_parts: list[str] = []

        try:
            # The append is serialized under the event-log session lock, so concurrent browser
            # requests cannot both consume the fifth and final prompt slot.
            history = await _build_message_history(db, session_id)
            await append_event(
                db,
                session_id=session_id,
                scenario_id=scenario_id,
                scenario_version=scenario_version,
                event_type="ai_prompt_submitted",
                actor="candidate",
                payload=AiPromptSubmittedPayload(turn_id=turn_id, prompt=content).model_dump(),
                max_event_type_count=("ai_prompt_submitted", MAX_CANDIDATE_TURNS),
            )

            llm = get_llm()
            if llm is None:
                raise RuntimeError("COHERE_API_KEY is not configured")

            scenario = get_scenario(scenario_id, scenario_version)
            system_prompt = _build_system_prompt(scenario)
            messages = history + [{"role": "user", "content": content}]

            tool_call_seq = 0

            while True:
                assistant_content = None
                stop_reason = None
                tool_calls: list[ToolCallChunk] = []

                async for chunk in llm.stream_turn(
                    system=system_prompt, messages=messages, tools=workspace_tools.COHERE_TOOL_SCHEMAS
                ):
                    if isinstance(chunk, TokenChunk):
                        yield _sse("token", {"text": chunk.text})
                        response_text_parts.append(chunk.text)
                    else:
                        total_input += chunk.usage.input_tokens
                        total_output += chunk.usage.output_tokens
                        assistant_content = chunk.raw_content
                        stop_reason = chunk.stop_reason
                        tool_calls = chunk.tool_calls

                messages.append(_assistant_message(assistant_content))

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

                messages.extend(_cohere_tool_result(result) for result in tool_results)

        except AppError as exc:
            # The response has already become an SSE stream, so domain rejections are emitted
            # as the documented error event instead of attempting to change the HTTP status.
            yield _sse("error", {"code": exc.code, "message": exc.message})
            return
        except Exception as exc:  # noqa: BLE001 — outage handling is intentionally broad (brief 02)
            # Vendor exceptions can contain request headers, provider trace IDs, and account
            # metadata. Preserve neither in the candidate-facing SSE stream nor in the event log.
            logger.warning("Simulation provider request failed (%s)", type(exc).__name__)
            message = SAFE_MODEL_UNAVAILABLE_MESSAGE
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
            model_label=get_settings().cohere_model,
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
            {
                "response_id": response_id,
                "usage": {"input_tokens": total_input, "output_tokens": total_output},
                "turn_limit": MAX_CANDIDATE_TURNS,
            },
        )
