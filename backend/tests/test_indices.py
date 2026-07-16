"""Layer 3 (ContextIndices) tests — compute_indices is pure, so fixtures are plain event dicts
shaped exactly like event_log.load_events' output (no DB needed at all)."""
import math

import pytest

from src.evaluation.indices import compute_indices


def _event(event_id, event_type, payload, elapsed_active_ms=0):
    return {
        "event_id": event_id,
        "event_type": event_type,
        "actor": "candidate",
        "occurred_at": "2026-07-16T02:00:00Z",
        "elapsed_active_ms": elapsed_active_ms,
        "payload": payload,
    }


def _by_id(indices, index_id):
    return next(i for i in indices if i["index_id"] == index_id)


def test_strong_session_hand_computed_values():
    events = [
        _event("e1", "evidence_viewed", {"artifact_id": "metrics_overview"}),
        _event("e2", "evidence_viewed", {"artifact_id": "application_logs"}),
        _event("e3", "evidence_viewed", {"artifact_id": "homepage_trace"}),
        _event("e4", "evidence_viewed", {"artifact_id": "homepage_orchestrator"}),
        _event("e5", "ai_prompt_submitted", {"turn_id": "t1", "prompt": "…"}),
        _event("e6", "ai_response_received", {"turn_id": "t1", "response_id": "r1", "model_label": "m", "usage": {"input_tokens": 800, "output_tokens": 200}}),
        _event("e7", "ai_prompt_submitted", {"turn_id": "t2", "prompt": "…"}),
        _event("e8", "ai_response_received", {"turn_id": "t2", "response_id": "r2", "model_label": "m", "usage": {"input_tokens": 700, "output_tokens": 300}}),
        _event("e9", "ai_suggestion_dispositioned", {"response_id": "r2", "option_id": "verify_then_adapt"}),
        _event("e10", "hypothesis_recorded", {"version": 1, "hypothesis_id": "redis_degradation", "confidence": 40, "trigger_evidence_ids": []}),
        _event("e11", "hypothesis_revised", {"previous_version": 1, "version": 2, "hypothesis_id": "sequential_independent_calls", "confidence": 85, "trigger_evidence_ids": ["homepage_trace"]}),
    ]
    q = 80.0
    indices = compute_indices(events, q)

    # e_p = Q / (1 + 0.05 * P * (1 + R_fail)); P=2, no failed tests / rejected dispositions -> R_fail=0
    e_p = _by_id(indices, "e_p")
    assert e_p["available"] is True
    assert e_p["value"] == pytest.approx(80.0 / (1 + 0.05 * 2 * 1))

    # epi = (Q/100) / (T/1000); T = 800+200+700+300 = 2000
    epi = _by_id(indices, "epi")
    assert epi["available"] is True
    assert epi["value"] == pytest.approx((80.0 / 100) / (2000 / 1000))

    # entropy: one view of each of the 4 evidence types -> perfectly even -> 1.0
    entropy = _by_id(indices, "investigation_entropy")
    assert entropy["available"] is True
    assert entropy["value"] == pytest.approx(1.0)

    # hypothesis_convergence: sequential_independent_calls is the 2nd distinct hypothesis -> HC = 1/2
    hc = _by_id(indices, "hypothesis_convergence")
    assert hc["available"] is True
    assert hc["value"] == pytest.approx(0.5)

    # ai_reliance: 1 disposition, verify_then_adapt (not accept_immediately) -> AR = 0/1 = 0.0
    ar = _by_id(indices, "ai_reliance")
    assert ar["available"] is True
    assert ar["value"] == pytest.approx(0.0)

    for idx in indices:
        if idx["value"] is not None:
            assert not math.isnan(idx["value"]) and not math.isinf(idx["value"])


def test_tunnel_vision_entropy_is_zero():
    events = [
        _event("e1", "evidence_viewed", {"artifact_id": "metrics_overview"}),
        _event("e2", "evidence_viewed", {"artifact_id": "metrics_overview"}),
        _event("e3", "evidence_viewed", {"artifact_id": "metrics_overview"}),
    ]
    entropy = _by_id(compute_indices(events, 50.0), "investigation_entropy")
    assert entropy["available"] is True
    assert entropy["value"] == pytest.approx(0.0)


def test_blind_acceptance_ai_reliance_is_one():
    events = [
        _event("e1", "ai_suggestion_dispositioned", {"response_id": "r1", "option_id": "accept_immediately"}),
        _event("e2", "ai_suggestion_dispositioned", {"response_id": "r2", "option_id": "accept_immediately"}),
    ]
    ar = _by_id(compute_indices(events, 50.0), "ai_reliance")
    assert ar["available"] is True
    assert ar["value"] == pytest.approx(1.0)


def test_no_ai_used_and_zero_inputs_are_unavailable_never_nan_or_inf():
    """An entirely empty session: every AI-dependent index reports unavailable with a reason;
    hypothesis_convergence still resolves to a real 0.0 (absence is a defined value, not a gap)."""
    indices = compute_indices([], 0.0)

    e_p = _by_id(indices, "e_p")
    assert e_p["available"] is False and e_p["value"] is None and e_p["reason"] == "no AI used"

    epi = _by_id(indices, "epi")
    assert epi["available"] is False and epi["value"] is None and epi["reason"] == "no AI used"

    entropy = _by_id(indices, "investigation_entropy")
    assert entropy["available"] is False and entropy["value"] is None

    hc = _by_id(indices, "hypothesis_convergence")
    assert hc["available"] is True
    assert hc["value"] == 0.0

    ar = _by_id(indices, "ai_reliance")
    assert ar["available"] is False and ar["value"] is None

    raw_counts = _by_id(indices, "raw_counts")
    assert raw_counts["ai_used"] is False

    for idx in indices:
        if idx["value"] is not None:
            assert not math.isnan(idx["value"]) and not math.isinf(idx["value"])


def test_epi_unavailable_when_ai_used_but_no_token_usage_recorded():
    events = [_event("e1", "ai_prompt_submitted", {"turn_id": "t1", "prompt": "…"})]
    epi = _by_id(compute_indices(events, 50.0), "epi")
    assert epi["available"] is False
    assert epi["reason"] == "no token usage recorded"
