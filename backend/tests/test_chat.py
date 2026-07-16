"""Contract tests for POST /api/chat."""

from collections.abc import AsyncIterator
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.chat import service as chat_service
from src.chat.router import router as chat_router
from src.exceptions import register_exception_handlers


class FakeLLM:
    def __init__(self, *, chunks: list[object]) -> None:
        self.chunks = chunks
        self.calls: list[dict] = []

    async def stream_turn(self, *, system: str, messages: list[dict], tools: list[dict]) -> AsyncIterator[object]:
        self.calls.append({"system": system, "messages": messages, "tools": tools})
        for chunk in self.chunks:
            yield chunk


def build_client() -> TestClient:
    app = FastAPI()
    register_exception_handlers(app)
    app.include_router(chat_router, prefix="/api")
    return TestClient(app)


def test_chat_success(monkeypatch):
    fake = FakeLLM(chunks=[SimpleNamespace(text="Redis"), SimpleNamespace(text=" latency")])
    monkeypatch.setattr(chat_service, "get_llm", lambda: fake)
    client = build_client()

    response = client.post(
        "/api/chat",
        json={"sessionId": "session-001", "message": "Can Redis explain the latency?"},
    )

    assert response.status_code == 200
    assert response.json() == {"reply": "Redis latency"}
    assert fake.calls[0]["tools"] == []
    assert fake.calls[0]["messages"] == [{"role": "user", "content": "Can Redis explain the latency?"}]


def test_chat_validation_failure_returns_400():
    client = build_client()

    response = client.post(
        "/api/chat",
        json={"sessionId": "session-001", "message": "   "},
    )

    assert response.status_code == 400
    body = response.json()
    assert body["error"]["code"] == "bad_request"


def test_chat_provider_failure_returns_502(monkeypatch):
    monkeypatch.setattr(chat_service, "get_llm", lambda: None)
    client = build_client()

    response = client.post(
        "/api/chat",
        json={"sessionId": "session-001", "message": "Can Redis explain the latency?"},
    )

    assert response.status_code == 502
    body = response.json()
    assert body["error"]["code"] == "ai_request_failed"
