"""Layer 1 — RuleGrader: deterministic, scored, pure. `rule_grade(events, submission, scenario)`.

Codex HIGH finding #1: criterion_id/points/dimension/kind for the 9 JSON-authored criteria come
from `scenario.criteria` — never re-typed here. Only the detection *predicates* (precedence and
presence over the event log, never a specific station order per the D-rule in
evidence-and-scoring.md) live in this module, plus the two backend-added graduated criteria
(evidence_coverage, verification_discipline) that are not scenario-authored (brief 04).

Codex HIGH finding #3 (dynamic denominator): `positive_points_available` sums only the positive
criteria that are NOT excluded — a criterion is excluded either by its own formula (VD with zero
dispositions) or globally by a `technical_error.excluded_criterion_ids` event (never penalize an
outage). Warnings never enter the denominator.
"""
from dataclasses import dataclass, field

BAD_HEALTHY_SIGNAL_HYPOTHESES = {"cpu_saturation", "database_slowdown"}
REQUIRED_VALIDATION_TEST_IDS = {"correctness_regression", "p95_latency"}
VERIFIED_DISPOSITION_OPTIONS = {"verify_then_adapt", "reject_suggestion"}

# Backend-added criteria (brief 04) are not in scenario.criteria — their id/dimension/label are
# defined here, once, since no scenario JSON owns them.
_BACKEND_CRITERIA = {
    "evidence_coverage": {"dimension": "evidence_use", "label": "View the pre-tagged relevant evidence before concluding."},
    "verification_discipline": {"dimension": "ai_verification", "label": "Verify or test AI suggestions instead of accepting them blindly."},
}


@dataclass
class CriterionResult:
    criterion_id: str
    dimension: str | None
    kind: str  # positive | warning
    points: float          # earned (0, configured_points, or graduated 0..configured_points)
    max_value: float       # configured positive points (0 for warnings and excluded criteria)
    status: str            # met | missed | excluded  ("met" on a warning = the penalty applied)
    evidence_refs: list[str]


@dataclass
class Layer1Result:
    criteria: list[CriterionResult] = field(default_factory=list)
    positive_points_available: float = 0.0
    total: float = 0.0
    normalized_q: float = 0.0


# --- event-log helpers -------------------------------------------------------

def _events_of_type(events: list[dict], event_type: str) -> list[dict]:
    return [e for e in events if e["event_type"] == event_type]


def _first_evidence_view(events: list[dict], artifact_id: str) -> dict | None:
    for e in events:
        if e["event_type"] == "evidence_viewed" and e["payload"].get("artifact_id") == artifact_id:
            return e
    return None


def _final_submission_event(events: list[dict]) -> dict | None:
    subs = _events_of_type(events, "final_submission")
    return subs[-1] if subs else None


def _first_fix_proposing_action(events: list[dict]) -> dict | None:
    """First of any test_executed, decision_recorded, or final_submission — the point past which
    the candidate is acting on a conclusion rather than still gathering evidence."""
    for e in events:
        if e["event_type"] in ("test_executed", "decision_recorded", "final_submission"):
            return e
    return None


def _excluded_criterion_ids(events: list[dict]) -> set[str]:
    """Collected from every technical_error event (D007: never penalize a platform outage)."""
    excluded: set[str] = set()
    for e in events:
        if e["event_type"] == "technical_error":
            excluded.update(e["payload"].get("excluded_criterion_ids", []))
    return excluded


def _refs(*events_or_none) -> list[str]:
    return [e["event_id"] for e in events_or_none if e]


# --- the 9 JSON-authored rules: each returns (points_if_met, status, evidence_refs) -----------
# `points_value` is the criterion's own configured_points (positive max or the warning's penalty).

def _rule_trace_before_change(events, submission, final_sub, points_value):
    trace_view = _first_evidence_view(events, "homepage_trace")
    fix_action = _first_fix_proposing_action(events)
    if trace_view and fix_action and trace_view["sequence"] < fix_action["sequence"]:
        return points_value, "met", _refs(trace_view)
    return 0.0, "missed", _refs(trace_view, fix_action) or _refs(final_sub)


def _rule_healthy_signals_used(events, submission, final_sub, points_value):
    metrics_view = _first_evidence_view(events, "metrics_overview")
    if not metrics_view:
        return 0.0, "missed", _refs(final_sub)
    for e in events:
        if e["sequence"] <= metrics_view["sequence"]:
            continue
        if (
            e["event_type"] in ("hypothesis_recorded", "hypothesis_revised")
            and e["payload"].get("hypothesis_id") in BAD_HEALTHY_SIGNAL_HYPOTHESES
        ):
            return 0.0, "missed", _refs(metrics_view, e)
    if submission.get("root_cause_id") in BAD_HEALTHY_SIGNAL_HYPOTHESES:
        return 0.0, "missed", _refs(metrics_view, final_sub)
    return points_value, "met", _refs(metrics_view)


def _rule_sequential_source_identified(events, submission, final_sub, points_value):
    source_view = _first_evidence_view(events, "homepage_orchestrator")
    if source_view and final_sub and source_view["sequence"] < final_sub["sequence"]:
        return points_value, "met", _refs(source_view)
    return 0.0, "missed", _refs(source_view, final_sub)


def _rule_independence_checked(events, submission, final_sub, points_value):
    for e in events:
        if e["event_type"] == "ai_suggestion_dispositioned" and e["payload"].get("option_id") == "verify_then_adapt":
            return points_value, "met", _refs(e)
    source_view = _first_evidence_view(events, "homepage_orchestrator")
    if "calls_are_independent" in submission.get("assumption_ids", []) and source_view:
        return points_value, "met", _refs(source_view, final_sub)
    return 0.0, "missed", _refs(final_sub)


def _rule_dual_validation_selected(events, submission, final_sub, points_value):
    # Real validation, not self-declared: credit only when the candidate's code ACTUALLY passed the
    # sandbox Run-Tests (submission.sandbox_passed). Legacy path: an explicit validation_test_ids
    # checklist still counts, so older full-form submissions grade unchanged.
    passed = bool(submission.get("sandbox_passed")) \
        or REQUIRED_VALIDATION_TEST_IDS <= set(submission.get("validation_test_ids") or [])
    if passed:
        cited = [
            e for e in events
            if e["event_type"] == "test_executed" and e["payload"].get("test_id") in REQUIRED_VALIDATION_TEST_IDS
        ]
        return points_value, "met", _refs(*cited) or _refs(final_sub)
    return 0.0, "missed", _refs(final_sub)


def _rule_revised_after_contradiction(events, submission, final_sub, points_value):
    for e in events:
        if e["event_type"] == "hypothesis_revised" and e["payload"].get("trigger_evidence_ids"):
            return points_value, "met", _refs(e)
    return 0.0, "missed", _refs(final_sub)


def _rule_unsupported_cpu_scaling(events, submission, final_sub, points_value):
    # Warning: "met" means the penalty applies.
    if submission.get("remediation_id") == "scale_cpu":
        return points_value, "met", _refs(final_sub)
    return 0.0, "missed", _refs(final_sub)


def _rule_unverified_ai_acceptance(events, submission, final_sub, points_value):
    for e in events:
        if e["event_type"] == "ai_suggestion_dispositioned" and e["payload"].get("option_id") == "accept_immediately":
            return points_value, "met", _refs(e)
    return 0.0, "missed", _refs(final_sub)


def _rule_diagnosis_without_evidence(events, submission, final_sub, points_value):
    # ponytail: the slim submit form no longer collects an evidence checklist. When the field is
    # omitted (None), this criterion doesn't apply — excluded from the max rather than penalising
    # every candidate -15. If present (legacy full form), keep the original "empty => uncited" rule.
    # NOTE for Seb: confirm "excluded" vs deriving cited evidence from viewed-artifact events.
    evidence = submission.get("supporting_evidence_ids")
    if evidence is None:
        return 0.0, "excluded", _refs(final_sub)
    if not evidence:
        return points_value, "met", _refs(final_sub)
    return 0.0, "missed", _refs(final_sub)


_JSON_RULE_HANDLERS = {
    "trace_before_change": _rule_trace_before_change,
    "healthy_signals_used": _rule_healthy_signals_used,
    "sequential_source_identified": _rule_sequential_source_identified,
    "independence_checked": _rule_independence_checked,
    "dual_validation_selected": _rule_dual_validation_selected,
    "revised_after_contradiction": _rule_revised_after_contradiction,
    "unsupported_cpu_scaling": _rule_unsupported_cpu_scaling,
    "unverified_ai_acceptance": _rule_unverified_ai_acceptance,
    "diagnosis_without_evidence": _rule_diagnosis_without_evidence,
}


# --- the 2 backend-added graduated (0-10) criteria (brief 04) ---------------------------------

def _rule_evidence_coverage(events, scenario, final_sub):
    """EC = |relevant_artifact_ids ∩ V_pre| / |relevant_artifact_ids|; V_pre = distinct
    evidence_viewed artifact_ids strictly before final_submission's sequence."""
    relevant = scenario.relevant_artifact_ids
    if not relevant:
        return 0.0, "missed", []
    cutoff = final_sub["sequence"] if final_sub else float("inf")
    first_view_by_artifact: dict[str, dict] = {}
    for e in events:
        if e["event_type"] != "evidence_viewed" or e["sequence"] >= cutoff:
            continue
        aid = e["payload"].get("artifact_id")
        if aid and aid not in first_view_by_artifact:
            first_view_by_artifact[aid] = e
    covered = [a for a in relevant if a in first_view_by_artifact]
    ec = len(covered) / len(relevant)
    points = round(10 * ec)
    refs = _refs(*(first_view_by_artifact[a] for a in covered)) or _refs(final_sub)
    return float(points), ("met" if points > 0 else "missed"), refs


def _rule_verification_discipline(events, submission, final_sub):
    """VD = N_verified / N_disp_total; excluded when N_disp_total == 0 (nothing to verify).
    A disposition counts as verified if its option is verify_then_adapt/reject_suggestion, OR it is
    followed (higher sequence, pre-submit) by a test_executed for the remediation ultimately chosen —
    i.e. the candidate empirically checked the suggestion even without formally rejecting/modifying it."""
    dispositions = _events_of_type(events, "ai_suggestion_dispositioned")
    n_total = len(dispositions)
    if n_total == 0:
        return 0.0, "excluded", []

    cutoff = final_sub["sequence"] if final_sub else float("inf")
    remediation_id = submission.get("remediation_id")
    verified_refs: list[str] = []
    n_verified = 0
    for d in dispositions:
        if d["payload"].get("option_id") in VERIFIED_DISPOSITION_OPTIONS:
            n_verified += 1
            verified_refs.append(d["event_id"])
            continue
        confirming_test = next(
            (
                e for e in events
                if d["sequence"] < e["sequence"] < cutoff
                and e["event_type"] == "test_executed"
                and e["payload"].get("remediation_id") == remediation_id
            ),
            None,
        )
        if confirming_test:
            n_verified += 1
            verified_refs.append(d["event_id"])
            verified_refs.append(confirming_test["event_id"])

    vd = n_verified / n_total
    points = round(10 * vd)
    refs = verified_refs or _refs(final_sub)
    return float(points), ("met" if points > 0 else "missed"), refs


# --- orchestration ------------------------------------------------------------------------------

def _finalize(criterion_id, dimension, kind, configured_points, excluded_ids, natural) -> CriterionResult:
    """Apply exclusion (own-formula or technical_error-driven) uniformly, then set max_value."""
    points, status, evidence_refs = natural
    if status == "excluded" or criterion_id in excluded_ids:
        return CriterionResult(criterion_id, dimension, kind, 0.0, 0.0, "excluded", [])
    max_value = configured_points if kind == "positive" else 0.0
    return CriterionResult(criterion_id, dimension, kind, points, max_value, status, evidence_refs)


def rule_grade(events: list[dict], submission: dict, scenario) -> Layer1Result:
    excluded_ids = _excluded_criterion_ids(events)
    final_sub = _final_submission_event(events)

    results: list[CriterionResult] = []

    for crit in scenario.criteria:
        cid = crit["criterion_id"]
        handler = _JSON_RULE_HANDLERS.get(cid)
        if handler is None:
            continue  # forward-compat: an unrecognized scenario-authored criterion is skipped, not invented
        natural = handler(events, submission, final_sub, crit["configured_points"])
        results.append(_finalize(cid, crit["dimension"], crit["kind"], crit["configured_points"], excluded_ids, natural))

    ec_natural = _rule_evidence_coverage(events, scenario, final_sub)
    results.append(_finalize("evidence_coverage", _BACKEND_CRITERIA["evidence_coverage"]["dimension"],
                              "positive", 10, excluded_ids, ec_natural))

    vd_natural = _rule_verification_discipline(events, submission, final_sub)
    results.append(_finalize("verification_discipline", _BACKEND_CRITERIA["verification_discipline"]["dimension"],
                              "positive", 10, excluded_ids, vd_natural))

    positive_points_available = sum(r.max_value for r in results if r.kind == "positive" and r.status != "excluded")
    total = sum(r.points for r in results)
    normalized_q = 0.0 if positive_points_available == 0 else max(0.0, total) / positive_points_available * 100

    return Layer1Result(
        criteria=results,
        positive_points_available=positive_points_available,
        total=total,
        normalized_q=normalized_q,
    )
