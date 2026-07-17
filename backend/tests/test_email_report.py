"""Tests for POST /sessions/{id}/email-report and the report email renderer.

SMTP is never touched: send_report_email is monkeypatched in the endpoint tests, and the renderer
test is a pure unit test over a handcrafted report dict. The panel is faked (no network), same as
test_report.py, so a session can reach `graded` offline.
"""
from types import SimpleNamespace

import pytest

from src.evaluation import panel as panel_module
from src.evaluation import router as router_module
from src.notifications import render_report_email

FAKE_CONFIGS = [
    panel_module.GraderConfig("groq", "fake-groq-key", "http://fake-groq", "fake-groq-model"),
    panel_module.GraderConfig("nim", "fake-nim-key", "http://fake-nim", "fake-nim-model"),
]


@pytest.fixture(autouse=True)
def _fake_panel(monkeypatch):
    async def fake_grade_once(vendor_cfg, dimension, digest):
        return {"score": 4, "justification": f"{vendor_cfg.vendor} opinion", "cited_event_ids": []}

    async def fake_narrative(vendor_cfg, digest):
        return "Evidence-led, depth-first investigation with one hypothesis revision."

    async def fake_questions(vendor_cfg, digest, missed_labels, flagged_dimensions):
        return ["Walk me through why you ruled out CPU saturation."]

    monkeypatch.setattr(panel_module, "_grader_configs", lambda: FAKE_CONFIGS)
    monkeypatch.setattr(panel_module, "_grade_once", fake_grade_once)
    monkeypatch.setattr(panel_module, "_grade_narrative_once", fake_narrative)
    monkeypatch.setattr(panel_module, "_grade_questions_once", fake_questions)


def _configure_email(monkeypatch):
    """Make the 'email configured?' gate pass without real creds (send is faked separately)."""
    monkeypatch.setattr(
        router_module,
        "get_settings",
        lambda: SimpleNamespace(
            email_smtp_host="smtp.example", email_smtp_port=587,
            email_smtp_user=None, email_password=None, email_address="from@example.com",
        ),
    )


async def _graded_session(client) -> str:
    resp = await client.post("/api/sessions", json={"display_name": "Test Candidate"})
    session_id = resp.json()["session_id"]
    for artifact_id in ("metrics_overview", "homepage_trace", "homepage_orchestrator"):
        await client.post(
            f"/api/sessions/{session_id}/events",
            json={"event_type": "evidence_viewed", "payload": {"artifact_id": artifact_id}},
        )
    for test_id in ("correctness_regression", "p95_latency"):
        await client.post(
            f"/api/sessions/{session_id}/tests/{test_id}",
            json={"remediation_id": "parallelize_confirmed_independent_calls"},
        )
    submission = {
        "root_cause_id": "sequential_independent_calls",
        "supporting_evidence_ids": ["homepage_trace", "homepage_orchestrator"],
        "remediation_id": "parallelize_confirmed_independent_calls",
        "expected_impact_id": "lower_p95_preserve_correctness",
        "risk_ids": ["dependency_order"],
        "assumption_ids": ["calls_are_independent"],
        "validation_test_ids": ["correctness_regression", "p95_latency"],
        "rollback_id": "restore_sequential_orchestration",
        "final_confidence": 85,
        "rationale": "Sequential awaits of independent lookups accumulate latency; parallelize them.",
    }
    resp = await client.post(f"/api/sessions/{session_id}/submit", json=submission)
    assert resp.json()["status"] == "graded", resp.text
    return session_id


async def test_email_report_sends_to_recipient(client, monkeypatch):
    _configure_email(monkeypatch)
    captured = {}
    monkeypatch.setattr(router_module, "send_report_email",
                        lambda to, report: captured.update(to=to, report=report))
    session_id = await _graded_session(client)

    resp = await client.post(f"/api/sessions/{session_id}/email-report", json={"email": "me@example.com"})
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"sent": True, "to": "me@example.com"}
    assert captured["to"] == "me@example.com"
    # The endpoint hands the real report through: all three layers are present for the renderer.
    assert set(captured["report"]["scores"]) == {"deterministic", "ai_analysis", "context_indices"}


async def test_email_report_409_before_submission(client, new_session, monkeypatch):
    _configure_email(monkeypatch)
    resp = await client.post(
        f"/api/sessions/{new_session['session_id']}/email-report", json={"email": "me@example.com"}
    )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "not_submitted"


async def test_email_report_422_on_bad_email(client, monkeypatch):
    _configure_email(monkeypatch)
    resp = await client.post("/api/sessions/any-id/email-report", json={"email": "not-an-email"})
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_email"


async def test_email_report_503_when_not_configured(client, monkeypatch):
    monkeypatch.setattr(
        router_module,
        "get_settings",
        lambda: SimpleNamespace(email_smtp_host=None, email_address=None),
    )
    resp = await client.post("/api/sessions/any-id/email-report", json={"email": "me@example.com"})
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "email_not_configured"


# --- renderer unit test: the D007/D009 layer boundaries must be visible in the HTML ---

_SAMPLE_REPORT = {
    "session": {"display_name": "Ada", "session_id": "s1"},
    "scores": {
        "deterministic": {
            "total": 60.0, "max": 70.0,  # real report uses Float columns; _fmt must render "60/70"
            "criteria": [{"criterion_id": "evidence_coverage", "label": "Evidence coverage",
                          "points": 10, "status": "met", "evidence_refs": ["s1:1"]}],
        },
        "ai_analysis": {
            "label": "AI analysis — model opinion, human review required",
            "dimensions": [{"dimension": "problem_framing", "score": 4, "scale": 5, "flagged": False,
                            "justification": "Framed symptom vs constraint before investigating.",
                            "cited_event_ids": [], "graders": ["g"]}],
            "narrative": {"text": "Depth-first.", "scored": False},
        },
        "context_indices": {
            "scored": False, "ai_used": True,
            "indices": [
                {"index_id": "e_p", "value": 42.5, "available": True,
                 "formula": "Q / (1 + 0.05*P_total*(1+R_fail))",
                 "inputs": {"Q": 60, "P_total": 5, "R_fail": 0.0}},
                {"index_id": "epi", "value": None, "formula": "(Q/100) / (T/1000)",
                 "inputs": {"Q": 60, "T": 0}, "available": False},
            ],
        },
    },
    "interview_questions": ["Why rule out CPU?"],
    "hypotheses": [{"version": 1, "hypothesis_id": "sequential_independent_calls",
                    "confidence": 80, "trigger_evidence_ids": ["homepage_trace"]}],
}


def test_render_makes_layer_boundaries_visible():
    subject, html, text = render_report_email(_SAMPLE_REPORT)
    low = html.lower()
    assert "60/70" in subject
    # Layer 2 label shown VERBATIM (the non-scoring signal).
    assert "ai analysis — model opinion, human review required" in low
    # Layer 3 disclaimer present; unavailable index degrades to n/a; glossary appendix present.
    assert "never scored" in low
    assert "n/a" in low
    assert "prompt efficiency" in low
    # No employment verdict anywhere.
    for phrase in ("should be hired", "should not be hired", "do not hire", "recommend hir"):
        assert phrase not in low


def test_render_shows_layer3_formula_and_inputs():
    _subject, html, _text = render_report_email(_SAMPLE_REPORT)
    assert "Q / (1 + 0.05*P_total*(1+R_fail))" in html   # formula rendered verbatim
    assert "Q=60" in html and "P_total=5" in html         # scalar inputs rendered


def test_render_layer2_is_description_led_with_hypotheses():
    _subject, html, _text = render_report_email(_SAMPLE_REPORT)
    assert "Framed symptom vs constraint before investigating." in html  # justification is the content
    assert "Hypotheses recorded" in html
    assert "sequential_independent_calls" in html


def test_render_uses_app_navy_palette():
    _subject, html, _text = render_report_email(_SAMPLE_REPORT)
    assert "#1c2b4d" in html  # navy header/accents matching the Godot app


def test_render_no_ai_used_path():
    report = {**_SAMPLE_REPORT}
    report["scores"] = {**report["scores"], "context_indices": {"scored": False, "ai_used": False, "indices": []}}
    _subject, html, _text = render_report_email(report)
    assert "no ai assistance used" in html.lower()
