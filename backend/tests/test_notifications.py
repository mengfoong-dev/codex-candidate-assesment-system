"""Best-effort report email: sends when configured, no-ops otherwise, never raises. No network."""
import json
from types import SimpleNamespace

import pytest

from src.notifications import service as notify

# Full build_report() shape — the HTML renderer reads all three layers, session, and appendix ids.
REPORT = {
    "session": {"session_id": "s1", "display_name": "Test Candidate"},
    "scores": {
        "deterministic": {
            "total": 60, "max": 80,
            "criteria": [{"criterion_id": "evidence_coverage", "label": "Evidence coverage",
                          "points": 10, "status": "met", "evidence_refs": []}],
        },
        "ai_analysis": {
            "label": "AI analysis — model opinion, human review required",
            "dimensions": [{"dimension": "evidence_use", "score": 4, "scale": 5, "flagged": False,
                            "justification": "Connected clues into a conclusion.",
                            "cited_event_ids": [], "graders": []}],
            "narrative": {"text": "Depth-first.", "scored": False},
        },
        "context_indices": {"scored": False, "ai_used": True, "indices": [
            {"index_id": "e_p", "value": 42.5, "available": True,
             "formula": "Q / (1 + 0.05*P)", "inputs": {"Q": 60, "P": 5}},
        ]},
    },
    "hypotheses": [{"hypothesis_id": "sequential_independent_calls", "version": 1, "confidence": 80}],
    "interview_questions": ["Why rule out CPU?"],
}


def _settings(**over):
    base = dict(
        email_api_key=None,
        email_smtp_host="smtp.test",
        email_smtp_port=587,
        email_smtp_user="login",
        email_password="pw",
        email_address="from@vibeproof.app",
    )
    base.update(over)
    return SimpleNamespace(**base)


class _FakeResponse:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self):
        return b'{"messageId":"<test>"}'


class _FakeSMTP:
    sent: list = []

    def __init__(self, host, port, timeout=0):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def starttls(self):
        pass

    def login(self, user, password):
        pass

    def send_message(self, msg):
        _FakeSMTP.sent.append(msg)


@pytest.mark.asyncio
async def test_sends_to_candidate_email_when_configured(monkeypatch):
    _FakeSMTP.sent = []
    monkeypatch.setattr(notify, "get_settings", lambda: _settings())
    monkeypatch.setattr(notify.smtplib, "SMTP", _FakeSMTP)

    sent = await notify.send_report_email(to_email="cand@example.com", report=REPORT)

    assert sent is True
    assert len(_FakeSMTP.sent) == 1
    msg = _FakeSMTP.sent[0]
    assert msg["To"] == "cand@example.com"
    assert msg["From"] == "from@vibeproof.app"
    assert "60/80" in msg["Subject"]
    text = msg.get_body(preferencelist=("plain",)).get_content()
    html = msg.get_body(preferencelist=("html",)).get_content()
    assert "60/80" in text                              # Layer 1 line in plain-text part
    assert "Layer 1" in html and "VibeProof" in html    # styled HTML template is the alternative part
    assert "not scored" in html.lower()                 # Layer 2/3 boundary visible (D007/D009)


@pytest.mark.asyncio
async def test_noop_when_smtp_unconfigured(monkeypatch):
    _FakeSMTP.sent = []
    monkeypatch.setattr(notify, "get_settings", lambda: _settings(email_password=None))
    monkeypatch.setattr(notify.smtplib, "SMTP", _FakeSMTP)

    sent = await notify.send_report_email(to_email="cand@example.com", report=REPORT)

    assert sent is False
    assert _FakeSMTP.sent == []


@pytest.mark.asyncio
async def test_noop_when_recipient_is_not_an_email(monkeypatch):
    _FakeSMTP.sent = []
    monkeypatch.setattr(notify, "get_settings", lambda: _settings())
    monkeypatch.setattr(notify.smtplib, "SMTP", _FakeSMTP)

    sent = await notify.send_report_email(to_email="Anonymous", report=REPORT)

    assert sent is False
    assert _FakeSMTP.sent == []


@pytest.mark.asyncio
async def test_delivery_failure_is_swallowed(monkeypatch):
    def boom(*a, **k):
        raise OSError("smtp down")

    monkeypatch.setattr(notify, "get_settings", lambda: _settings())
    monkeypatch.setattr(notify.smtplib, "SMTP", boom)

    sent = await notify.send_report_email(to_email="cand@example.com", report=REPORT)

    assert sent is False  # best-effort: never raises


@pytest.mark.asyncio
async def test_prefers_brevo_api_when_key_set(monkeypatch):
    _FakeSMTP.sent = []
    captured = {}

    def fake_urlopen(req, timeout=0):
        captured["url"] = req.full_url
        captured["api_key"] = req.headers.get("Api-key")
        captured["body"] = json.loads(req.data.decode())
        return _FakeResponse()

    monkeypatch.setattr(notify, "get_settings", lambda: _settings(email_api_key="xkeysib-abc"))
    monkeypatch.setattr(notify.urllib.request, "urlopen", fake_urlopen)
    monkeypatch.setattr(notify.smtplib, "SMTP", _FakeSMTP)  # must NOT be used

    sent = await notify.send_report_email(to_email="cand@example.com", report=REPORT)

    assert sent is True
    assert _FakeSMTP.sent == []  # API preferred over SMTP
    assert captured["url"] == notify._BREVO_API_URL
    assert captured["api_key"] == "xkeysib-abc"
    assert captured["body"]["to"][0]["email"] == "cand@example.com"
    assert captured["body"]["sender"]["email"] == "from@vibeproof.app"
    assert "60/80" in captured["body"]["textContent"]        # plain-text part
    assert "Layer 1" in captured["body"]["htmlContent"]        # styled HTML part now sent via API too


@pytest.mark.asyncio
async def test_api_failure_is_swallowed(monkeypatch):
    def boom(*a, **k):
        raise OSError("api down")

    monkeypatch.setattr(notify, "get_settings", lambda: _settings(email_api_key="xkeysib-abc"))
    monkeypatch.setattr(notify.urllib.request, "urlopen", boom)

    sent = await notify.send_report_email(to_email="cand@example.com", report=REPORT)

    assert sent is False  # best-effort: never raises


@pytest.mark.asyncio
async def test_noop_when_neither_api_nor_smtp(monkeypatch):
    monkeypatch.setattr(notify, "get_settings", lambda: _settings(email_api_key=None, email_password=None))

    sent = await notify.send_report_email(to_email="cand@example.com", report=REPORT)

    assert sent is False
