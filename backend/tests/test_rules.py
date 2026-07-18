"""Layer 1 (RuleGrader) tests. rule_grade is pure, but the fixtures are built as real Event rows
(via tests/helpers.py) so the shape matches exactly what event_log.load_events returns in
production. This only needs the `events`/`scoring_results` tables — not the domain routers other
implementers are still building — so schema creation is done locally instead of via conftest's
`app` fixture (which imports every domain router through src.main).
"""
import pytest
import pytest_asyncio

from src.database import AsyncSessionLocal
from src.event_log import load_events
from src.registry import get_scenario

from src.evaluation.rules import rule_grade

from tests.helpers import build_log

SCENARIO = get_scenario("homepage_latency", "1.0.0")


@pytest_asyncio.fixture
async def db():
    from src import models  # noqa: F401 — registers tables on Base.metadata
    from src.database import Base, engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)


async def _graded(session_id: str, events: list[tuple]):
    await build_log(session_id, events)
    async with AsyncSessionLocal() as s:
        loaded = await load_events(s, session_id)
    final = next(e for e in reversed(loaded) if e["event_type"] == "final_submission")
    return rule_grade(loaded, final["payload"], SCENARIO), loaded


def _by_id(result, criterion_id):
    return next(c for c in result.criteria if c.criterion_id == criterion_id)


def _submission(**overrides):
    base = dict(
        root_cause_id="sequential_independent_calls",
        supporting_evidence_ids=["homepage_trace", "homepage_orchestrator"],
        remediation_id="parallelize_confirmed_independent_calls",
        expected_impact_id="lower_p95_preserve_correctness",
        risk_ids=["dependency_order"],
        assumption_ids=["calls_are_independent"],
        validation_test_ids=["correctness_regression", "p95_latency"],
        rollback_id="restore_sequential_orchestration",
        final_confidence=85,
        rationale="Sequential awaits of independent lookups accumulate latency; parallelize them.",
    )
    base.update(overrides)
    return base


async def test_strong_session_all_positive_rules_met_no_negatives(db):
    result, _ = await _graded(
        "sess-strong",
        [
            ("evidence_viewed", {"artifact_id": "metrics_overview"}),
            ("evidence_viewed", {"artifact_id": "homepage_trace"}),
            ("evidence_viewed", {"artifact_id": "homepage_orchestrator"}),
            ("ai_suggestion_dispositioned", {"response_id": "safe_concurrency_response_v1", "option_id": "verify_then_adapt"}),
            ("hypothesis_recorded", {"version": 1, "hypothesis_id": "redis_degradation", "confidence": 40, "trigger_evidence_ids": []}),
            ("hypothesis_revised", {"previous_version": 1, "version": 2, "hypothesis_id": "sequential_independent_calls", "confidence": 85, "trigger_evidence_ids": ["homepage_trace"]}),
            ("test_executed", {"test_id": "correctness_regression", "remediation_id": "parallelize_confirmed_independent_calls", "expected_result": "…", "actual_result": "12 of 12 passed", "status": "passed"}),
            ("test_executed", {"test_id": "p95_latency", "remediation_id": "parallelize_confirmed_independent_calls", "expected_result": "…", "actual_result": "310 ms", "status": "passed"}),
            ("final_submission", _submission()),
        ],
    )

    for cid in (
        "trace_before_change", "healthy_signals_used", "sequential_source_identified",
        "independence_checked", "dual_validation_selected", "revised_after_contradiction",
    ):
        c = _by_id(result, cid)
        assert c.status == "met", cid
        assert c.points == 10
        assert c.evidence_refs, f"{cid} missing evidence_refs"

    for cid in ("unsupported_cpu_scaling", "unverified_ai_acceptance", "diagnosis_without_evidence"):
        c = _by_id(result, cid)
        assert c.status == "missed"  # warning "missed" = no penalty applied
        assert c.points == 0

    ec = _by_id(result, "evidence_coverage")
    assert ec.status == "met" and ec.points == 10  # all 3 relevant artifacts viewed pre-submit

    vd = _by_id(result, "verification_discipline")
    assert vd.status == "met" and vd.points == 10  # the one disposition was verify_then_adapt

    assert result.positive_points_available == 80
    assert result.total == 80
    assert result.normalized_q == 100.0


async def test_blind_acceptance_fires_unverified_ai_acceptance(db):
    result, events = await _graded(
        "sess-blind",
        [
            ("ai_suggestion_dispositioned", {"response_id": "safe_concurrency_response_v1", "option_id": "accept_immediately"}),
            ("final_submission", _submission(validation_test_ids=[])),
        ],
    )
    disposition_event = next(e for e in events if e["event_type"] == "ai_suggestion_dispositioned")

    c = _by_id(result, "unverified_ai_acceptance")
    assert c.status == "met"  # warning "met" = penalty applied
    assert c.points == -10
    assert c.evidence_refs == [disposition_event["event_id"]]


async def test_sandbox_passed_grants_dual_validation_without_a_checklist(db):
    # Real validation, not self-declared: passing the Codex sandbox earns rule 5 even with an empty
    # validation_test_ids checklist.
    result, _ = await _graded(
        "sess-sandbox-pass",
        [
            ("test_executed", {"test_id": "correctness_regression", "status": "passed"}),
            ("test_executed", {"test_id": "p95_latency", "status": "passed"}),
            ("final_submission", _submission(sandbox_passed=True, validation_test_ids=[])),
        ],
    )
    c = _by_id(result, "dual_validation_selected")
    assert c.status == "met" and c.points == 10


async def test_no_sandbox_pass_and_no_checklist_misses_dual_validation(db):
    result, _ = await _graded(
        "sess-sandbox-fail",
        [("final_submission", _submission(sandbox_passed=False, validation_test_ids=[]))],
    )
    c = _by_id(result, "dual_validation_selected")
    assert c.status == "missed" and c.points == 0


async def test_slim_form_excludes_uncited_diagnosis_when_evidence_not_collected(db):
    # The slim submit form doesn't collect an evidence checklist (None) -> rule 9 is excluded from
    # the max rather than penalising every candidate -15.
    result, _ = await _graded(
        "sess-slim",
        [("final_submission", _submission(supporting_evidence_ids=None, validation_test_ids=[]))],
    )
    c = _by_id(result, "diagnosis_without_evidence")
    assert c.status == "excluded" and c.points == 0


async def test_scale_cpu_submission_fires_unsupported_cpu_scaling(db):
    result, events = await _graded(
        "sess-cpu",
        [("final_submission", _submission(remediation_id="scale_cpu", root_cause_id="cpu_saturation", validation_test_ids=[]))],
    )
    final = events[-1]

    c = _by_id(result, "unsupported_cpu_scaling")
    assert c.status == "met"
    assert c.points == -10
    assert c.evidence_refs == [final["event_id"]]


async def test_empty_supporting_evidence_fires_diagnosis_without_evidence(db):
    result, _ = await _graded(
        "sess-no-evidence",
        [("final_submission", _submission(supporting_evidence_ids=[], validation_test_ids=[]))],
    )
    c = _by_id(result, "diagnosis_without_evidence")
    assert c.status == "met"
    assert c.points == -15


async def test_outage_excludes_criteria_and_normalizes_correctly(db):
    """A technical_error mid-session excludes independence_checked from scoring; verification_discipline
    is excluded on its own (no dispositions ever happened — nothing to verify). Both drop out of the
    denominator entirely rather than being penalized as "missed" (D007: never penalize an outage)."""
    result, _ = await _graded(
        "sess-outage",
        [
            ("evidence_viewed", {"artifact_id": "metrics_overview"}),
            ("evidence_viewed", {"artifact_id": "homepage_trace"}),
            ("test_executed", {"test_id": "correctness_regression", "remediation_id": "parallelize_confirmed_independent_calls", "expected_result": "…", "actual_result": "12 of 12 passed", "status": "passed"}),
            ("test_executed", {"test_id": "p95_latency", "remediation_id": "parallelize_confirmed_independent_calls", "expected_result": "…", "actual_result": "310 ms", "status": "passed"}),
            ("technical_error", {"source": "simulation", "message": "AI vendor outage mid-session", "excluded_criterion_ids": ["independence_checked"]}),
            ("final_submission", _submission(assumption_ids=["none"])),
        ],
    )

    independence = _by_id(result, "independence_checked")
    assert independence.status == "excluded"
    assert independence.max_value == 0
    assert independence.points == 0

    vd = _by_id(result, "verification_discipline")
    assert vd.status == "excluded"  # zero dispositions -> nothing to verify, excluded by its own formula

    # homepage_orchestrator was never viewed: sequential_source_identified + part of EC both "missed"
    # (not excluded) so they still count against the denominator.
    assert _by_id(result, "sequential_source_identified").status == "missed"

    ec = _by_id(result, "evidence_coverage")
    assert ec.points == 7  # 2 of 3 relevant artifacts viewed -> round(10 * 2/3) == 7

    # 6 non-excluded positive criteria remain in the denominator: trace(10) + healthy(10) +
    # sequential_source(10, missed but not excluded) + dual_validation(10) + revised(10, missed) + EC(10)
    assert result.positive_points_available == 60
    # earned: trace(10) + healthy(10) + sequential_source(0) + dual_validation(10) + revised(0) + EC(7)
    assert result.total == 37
    assert result.normalized_q == pytest.approx(37 / 60 * 100)
