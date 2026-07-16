"""Chat orchestration for the candidate prompting screen.

This module keeps the backend thin: validate request inputs, call the configured Gemini
provider through a small seam, and return the final text response. No persistence, no
streaming, no scoring, and no session lifecycle logic.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass

from src.config import get_settings
from src.exceptions import AppError
from src.schemas import TokenUsage

SYSTEM_PROMPT = (
    "You are a general-purpose engineering copilot inside the candidate prompting screen for "
    "VibeProof. Answer clearly and concisely, and do not invent facts."
)


@dataclass(frozen=True)
class TokenChunk:
    text: str


@dataclass(frozen=True)
class TurnDone:
    stop_reason: str
    usage: TokenUsage | None = None
    tool_calls: list[object] | None = None
    raw_content: object | None = None


class GeminiLLM:
    """Small wrapper around the Google GenAI client.

    The chat endpoint only needs one complete assistant turn, so this wrapper normalizes the
    Gemini response into the same `stream_turn` seam used by the tests.
    """

    def __init__(self, *, api_key: str, model: str):
        from google import genai

        self._client = genai.Client(api_key=api_key)
        self._model = model

    async def stream_turn(self, *, system: str, messages: list[dict], tools: list[dict]):
        del tools  # This MVP does not use tools for candidate chat.

        user_text = "\n".join(
            str(item.get("content", "")).strip()
            for item in messages
            if isinstance(item, dict) and item.get("role") == "user"
        ).strip()
        prompt = f"{system}\n\nUser: {user_text}\nAssistant:"

        interaction = await asyncio.to_thread(
            self._client.interactions.create,
            model=self._model,
            input=prompt,
        )

        text = (getattr(interaction, "output_text", "") or "").strip()
        usage = getattr(interaction, "usage", None)
        yield TokenChunk(text=text)
        yield TurnDone(
            stop_reason=getattr(interaction, "status", None) or "completed",
            usage=TokenUsage(
                input_tokens=getattr(usage, "total_input_tokens", 0) or 0,
                output_tokens=getattr(usage, "total_output_tokens", 0) or 0,
            ),
            tool_calls=[],
            raw_content=interaction,
        )


def get_llm():
    """Return the configured Gemini provider if an API key is present."""
    settings = get_settings()
    if not settings.gemini_api_key:
        return None
    if not settings.gemini_chat_model:
        raise ValueError("gemini_chat_model is not configured")
    return GeminiLLM(api_key=settings.gemini_api_key, model=settings.gemini_chat_model)


def _extract_text(content: object) -> str | None:
    if isinstance(content, str):
        text = content.strip()
        return text or None

    if isinstance(content, list):
        parts = [piece for item in content if (piece := _extract_text(item))]
        text = "".join(parts).strip()
        return text or None

    if isinstance(content, dict):
        for key in ("text", "content", "value"):
            value = content.get(key)
            if value is None:
                continue
            extracted = _extract_text(value)
            if extracted:
                return extracted
        return None

    return None


async def _collect_reply(messages) -> tuple[str, object | None]:
    reply_chunks: list[str] = []
    final_content: object | None = None

    async for chunk in messages:
        if isinstance(getattr(chunk, "text", None), str):
            reply_chunks.append(chunk.text)
        if hasattr(chunk, "raw_content"):
            final_content = chunk.raw_content

    reply = "".join(reply_chunks).strip()
    if reply:
        return reply, final_content
    if final_content is not None:
        fallback = _extract_text(final_content)
        if fallback:
            return fallback, final_content
    return "", final_content


async def generate_reply(*, session_id: str, message: str) -> str:
    session_id = session_id.strip()
    message = message.strip()

    if not session_id:
        raise AppError("bad_request", "sessionId is required", 400)
    if not message:
        raise AppError("bad_request", "message is required", 400)

    llm = get_llm()
    if llm is None:
        raise AppError("ai_request_failed", "Unable to contact AI provider.", 502)

    try:
        reply, _ = await _collect_reply(
            llm.stream_turn(
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": message}],
                tools=[],
            )
        )
    except AppError:
        raise
    except Exception as exc:  # noqa: BLE001 - upstream/provider failures are mapped to 502
        raise AppError("ai_request_failed", "Unable to contact AI provider.", 502) from exc

    if not reply:
        raise AppError("ai_request_failed", "Unable to contact AI provider.", 502)

    return reply
