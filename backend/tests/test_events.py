"""POST /sessions/{id}/events — the anti-forgery gate: whitelist, typed shape, ID membership,
state checks, and post-submit lockout."""
import pytest


async def test_evidence_viewed_valid(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "evidence_viewed", "payload": {"artifact_id": "metrics_overview"}},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["sequence"] == 2  # assessment_opened already claimed sequence 1


async def test_evidence_viewed_unknown_artifact_id_422(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "evidence_viewed", "payload": {"artifact_id": "not_real"}},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_event_ids"


async def test_candidate_ai_prompt_accepted(new_session, client):
    """The candidate's free-text Codex prompt now streams in as a frontend event (was 422 before the
    wiring). It carries no scenario IDs, so it passes membership validation and is recorded for the
    Layer-2 rubric."""
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "candidate_ai_prompt", "payload": {"text": "Which downstream calls can run concurrently?"}},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["event_type"] == "candidate_ai_prompt"


async def test_candidate_senior_question_accepted(new_session, client):
    """Parallels candidate_ai_prompt: raw free-text to the in-scenario senior engineer, no scenario
    IDs to check, so it passes membership validation and feeds the Layer-2 digest."""
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "candidate_senior_question", "payload": {"text": "Has this happened before?"}},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["event_type"] == "candidate_senior_question"


async def test_station_visited_accepted(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "station_visited", "payload": {"station_id": "metrics_desk", "station_kind": "investigation"}},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["event_type"] == "station_visited"


async def test_station_visited_forged_station_id_still_accepted_but_unscored(new_session, client):
    """station_visited carries no scenario IDs, so validate_event_ids has no branch for it (by
    design — Layer-3 context, D009). A made-up station_id is shape-valid and gets recorded, but it
    can never earn Layer-1 points since no rule reads this event type."""
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "station_visited", "payload": {"station_id": "not_a_real_station"}},
    )
    assert resp.status_code == 201, resp.text


async def test_evidence_viewed_with_station_context_still_validates_artifact_id(new_session, client):
    """The two new optional context fields on evidence_viewed don't loosen the existing artifact_id
    membership check."""
    session_id = new_session["session_id"]
    ok = await client.post(
        f"/api/sessions/{session_id}/events",
        json={
            "event_type": "evidence_viewed",
            "payload": {"artifact_id": "metrics_overview", "station_id": "metrics_desk", "evidence_type": "metrics"},
        },
    )
    assert ok.status_code == 201, ok.text

    bad = await client.post(
        f"/api/sessions/{session_id}/events",
        json={
            "event_type": "evidence_viewed",
            "payload": {"artifact_id": "not_real", "station_id": "metrics_desk"},
        },
    )
    assert bad.status_code == 422
    assert bad.json()["error"]["code"] == "invalid_event_ids"


async def test_backend_only_event_type_rejected(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "ai_response_received", "payload": {}},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "event_type_not_allowed"


async def test_unknown_event_type_422(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "totally_made_up", "payload": {}},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "event_type_not_allowed"


async def test_hypothesis_revised_empty_trigger_422(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={
            "event_type": "hypothesis_revised",
            "payload": {
                "previous_version": 1,
                "version": 2,
                "hypothesis_id": "redis_degradation",
                "confidence": 50,
                "trigger_evidence_ids": [],  # empty trigger fails shape validation (min_length=1)
            },
        },
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_payload"


async def test_ai_suggestion_dispositioned_unseen_response_id_422(new_session, client):
    session_id = new_session["session_id"]
    resp = await client.post(
        f"/api/sessions/{session_id}/events",
        json={
            "event_type": "ai_suggestion_dispositioned",
            "payload": {"response_id": "safe_concurrency_response_v1", "option_id": "accept_immediately"},
        },
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "response_not_seen"


async def test_hypothesis_revised_stale_version_422(new_session, client):
    session_id = new_session["session_id"]

    record = {
        "event_type": "hypothesis_recorded",
        "payload": {
            "version": 1,
            "hypothesis_id": "redis_degradation",
            "confidence": 40,
            "trigger_evidence_ids": ["homepage_p95_increased"],
        },
    }
    assert (await client.post(f"/api/sessions/{session_id}/events", json=record)).status_code == 201

    revise_ok = {
        "event_type": "hypothesis_revised",
        "payload": {
            "previous_version": 1,
            "version": 2,
            "hypothesis_id": "sequential_independent_calls",
            "confidence": 70,
            "trigger_evidence_ids": ["sequential_awaits_in_code"],
        },
    }
    ok_resp = await client.post(f"/api/sessions/{session_id}/events", json=revise_ok)
    assert ok_resp.status_code == 201, ok_resp.text

    # version=2 again does not exceed the max already recorded (2) — shape-valid, state-invalid.
    stale = await client.post(
        f"/api/sessions/{session_id}/events",
        json={
            "event_type": "hypothesis_revised",
            "payload": {
                "previous_version": 1,
                "version": 2,
                "hypothesis_id": "redis_degradation",
                "confidence": 60,
                "trigger_evidence_ids": ["homepage_p95_increased"],
            },
        },
    )
    assert stale.status_code == 422
    assert stale.json()["error"]["code"] == "stale_hypothesis_version"


_SUBMISSION = {
    "root_cause_id": "sequential_independent_calls",
    "supporting_evidence_ids": [],
    "remediation_id": "parallelize_confirmed_independent_calls",
    "expected_impact_id": "lower_p95_preserve_correctness",
    "risk_ids": [],
    "assumption_ids": [],
    "validation_test_ids": [],
    "rollback_id": "no_rollback",
    "final_confidence": 80,
    "rationale": "Trace and source both point to sequential independent lookups.",
}


async def test_event_rejected_after_submit_409(new_session, client, monkeypatch):
    evaluation_service = pytest.importorskip(
        "src.evaluation.service", reason="src.evaluation not implemented yet — integration-only"
    )

    async def _noop(db, session_id):
        return None

    monkeypatch.setattr(evaluation_service, "run_evaluation", _noop)

    session_id = new_session["session_id"]
    submit_resp = await client.post(f"/api/sessions/{session_id}/submit", json=_SUBMISSION)
    assert submit_resp.status_code == 200, submit_resp.text

    late = await client.post(
        f"/api/sessions/{session_id}/events",
        json={"event_type": "evidence_viewed", "payload": {"artifact_id": "metrics_overview"}},
    )
    assert late.status_code == 409
