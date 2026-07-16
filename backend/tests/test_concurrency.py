"""Concurrency guarantees (Codex HIGH finding #5): sequence allocation and the submit compare-
and-set are serialized per session even under concurrent requests."""
import asyncio

import pytest


async def test_concurrent_events_get_unique_contiguous_sequences(new_session, client):
    session_id = new_session["session_id"]

    async def _post(i):
        return await client.post(
            f"/api/sessions/{session_id}/events",
            json={"event_type": "search_performed", "payload": {"query": f"q{i}"}},
        )

    responses = await asyncio.gather(*(_post(i) for i in range(20)))
    assert all(r.status_code == 201 for r in responses), [r.text for r in responses if r.status_code != 201]

    sequences = sorted(r.json()["sequence"] for r in responses)
    assert len(set(sequences)) == 20  # no two concurrent writers collided on the same sequence
    # assessment_opened already claimed sequence 1, so the 20 events occupy 2..21 contiguously.
    assert sequences == list(range(2, 22))


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


async def test_concurrent_submit_only_one_succeeds(new_session, client, monkeypatch):
    evaluation_service = pytest.importorskip(
        "src.evaluation.service", reason="src.evaluation not implemented yet — integration-only"
    )

    async def _noop(db, session_id):
        return None

    monkeypatch.setattr(evaluation_service, "run_evaluation", _noop)

    session_id = new_session["session_id"]

    async def _submit():
        return await client.post(f"/api/sessions/{session_id}/submit", json=_SUBMISSION)

    r1, r2 = await asyncio.gather(_submit(), _submit())
    assert sorted([r1.status_code, r2.status_code]) == [200, 409]
