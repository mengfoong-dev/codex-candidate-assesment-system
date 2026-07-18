"""Best-effort report email: sends when configured, no-ops otherwise, never raises. No network."""
from types import SimpleNamespace

import pytest

from src.notifications import service as notify

REPORT = {
    "scores": {
        "deterministic": {"total": 60, "max": 80},
        "ai_analysis": {"dimensions": [{"dimension": "evidence_use", "score": 4}]},
    }
}


def _settings(**over):
    base = dict(
        email_smtp_host="smtp.test",
        email_smtp_port=587,
        email_smtp_user="login",
        email_password="pw",
        email_address="from@vibeproof.app",
    )
    base.update(over)
    return SimpleNamespace(**base)


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
    assert "60 / 80" in msg.get_content()
    assert "evidence_use: 4/5" in msg.get_content()


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
