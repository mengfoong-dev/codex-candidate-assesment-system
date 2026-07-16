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
