"""End-to-end Proof Replay test: create a session, post the observable events an active session
would produce, submit, and read back the report. This needs the sessions/events/workspace/
simulation domains (owned by the other implementers) to exist behind `client` — until they land
this will fail at collection/run time, not because of a bug here; the shapes below follow the
frozen contract (docs/backend/00-api-contract.md) exactly so it's ready to run once integrated.
The panel's vendor calls are monkeypatched to fakes throughout — no network access.
"""
import pytest

from src.evaluation import panel as panel_module

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


async def test_report_has_all_three_layers_with_provenance(client, new_session):
    session_id = new_session["session_id"]

    for artifact_id in ("metrics_overview", "homepage_trace", "homepage_orchestrator"):
        resp = await client.post(
            f"/api/sessions/{session_id}/events",
            json={"event_type": "evidence_viewed", "payload": {"artifact_id": artifact_id}},
        )
        assert resp.status_code == 201, resp.text
    # Godot-only navigation events: Layer-3 CONTEXT (D009), never scored — the report surfaces them
    # under stations_visited, not inside scores.deterministic.
    for station_id in ("metrics_desk", "trace_desk", "metrics_desk"):
        resp = await client.post(
            f"/api/sessions/{session_id}/events",
            json={"event_type": "station_visited", "payload": {"station_id": station_id}},
        )
        assert resp.status_code == 201, resp.text
    # No ai_suggestion_dispositioned here: the events domain only accepts a disposition once the
    # simulation engine has actually produced that response_id (anti-forgery — you can't disposition
    # a suggestion you were never shown), which means driving a real chat turn — out of scope for
    # this report-assembly test. verification_discipline is correctly "excluded" below as a result
    # (brief 04: N_disp_total == 0 -> nothing to verify, not a penalty).
    for test_id in ("correctness_regression", "p95_latency"):
        resp = await client.post(
            f"/api/sessions/{session_id}/tests/{test_id}",
            json={"remediation_id": "parallelize_confirmed_independent_calls"},
        )
        assert resp.status_code == 200, resp.text

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
    submit_resp = await client.post(f"/api/sessions/{session_id}/submit", json=submission)
    assert submit_resp.status_code == 200, submit_resp.text
    assert submit_resp.json()["status"] == "graded"

    report_resp = await client.get(f"/api/sessions/{session_id}/report")
    assert report_resp.status_code == 200, report_resp.text
    report = report_resp.json()

    deterministic = report["scores"]["deterministic"]
    # No AI disposition happened (see above), so verification_discipline is excluded from the
    # denominator: 80 - 10 = 70.
    assert deterministic["max"] == 70
    criteria_by_id = {c["criterion_id"]: c for c in deterministic["criteria"]}
    assert criteria_by_id["verification_discipline"]["status"] == "excluded"
    for status in ("trace_before_change", "healthy_signals_used", "sequential_source_identified",
                    "independence_checked", "dual_validation_selected", "evidence_coverage"):
        assert criteria_by_id[status]["status"] == "met"
        assert criteria_by_id[status]["points"] == 10
    for c in deterministic["criteria"]:
        if c["status"] in ("met", "missed"):
            assert c["evidence_refs"], c["criterion_id"]  # provenance mandatory for met/missed

    ai_analysis = report["scores"]["ai_analysis"]
    assert len(ai_analysis["dimensions"]) == 7
    for d in ai_analysis["dimensions"]:
        assert d["cited_event_ids"] is not None
        assert d["graders"]
    assert ai_analysis["narrative"]["scored"] is False

    context_indices = report["scores"]["context_indices"]
    assert context_indices["scored"] is False
    assert context_indices["indices"]

    # stations_visited is display-only context: distinct stations in first-seen order, no dedup
    # collapsing the kind/first_sequence fields, and it never leaks into the scored deterministic block.
    assert report["stations_visited"] == [
        {"station_id": "metrics_desk", "station_kind": "investigation", "first_sequence": 5},
        {"station_id": "trace_desk", "station_kind": "investigation", "first_sequence": 6},
    ]
    deterministic_criterion_ids = {c["criterion_id"] for c in deterministic["criteria"]}
    assert "metrics_desk" not in deterministic_criterion_ids and "trace_desk" not in deterministic_criterion_ids

    assert report["interview_questions"] == ["Walk me through why you ruled out CPU saturation."]
    assert "human_review" in report["notices"]

    # D007/D009: never an employment verdict inside the AI-generated content itself. (`notices` is
    # excluded from this check — it correctly *disclaims* an employment decision, e.g. "does not
    # make an employment decision", which would otherwise false-positive on these phrases.)
    ai_generated_text = str(report["scores"]["ai_analysis"]).lower() + str(report["interview_questions"]).lower()
    for phrase in ("recommend hir", "should be hired", "should not be hired", "do not hire", "reject the candidate", "you should hire"):
        assert phrase not in ai_generated_text


async def test_report_404_before_submission(client, new_session):
    resp = await client.get(f"/api/sessions/{new_session['session_id']}/report")
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "not_submitted"


def test_build_digest_includes_candidate_prompt_text():
    """The Layer-2 digest must surface the candidate's streamed prompt so the rubric can grade
    prompt_precision. Before the wiring, candidate_ai_prompt events were dropped and this text was
    invisible to the grader."""
    events = [
        {
            "event_id": "e1",
            "event_type": "candidate_ai_prompt",
            "payload": {"text": "List the downstream calls and tell me which are independent."},
        }
    ]
    digest = panel_module._build_digest(events, submission={})
    assert "List the downstream calls" in digest
