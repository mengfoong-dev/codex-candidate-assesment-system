"""Assembles the Proof Replay report from scoring_results + events, matching the frozen shape in
docs/backend/00-api-contract.md (GET /report) exactly. `build_report(db, session_id) -> dict`.

Provenance is visible in the payload itself: every deterministic criterion carries evidence_refs,
every AI dimension carries cited_event_ids + grader provenance, every index carries formula+inputs
— the three-layer boundary (D007/D009) is something the recruiter can SEE, not just trust.

Router-level checks (409 until submitted, 503 + manual_review) live in router.py; this function
assumes it is only called once those preconditions hold, but still re-fetches the session itself
since it needs it for the `session` block of the report.
"""
import json

from sqlalchemy import select

from src.exceptions import AppError
from src.event_log import load_events
from src.models import ScoringResult, Session
from src.registry import get_scenario

_BACKEND_CRITERION_LABELS = {
    "evidence_coverage": "View the pre-tagged relevant evidence before concluding.",
    "verification_discipline": "Verify or test AI suggestions instead of accepting them blindly.",
}

_TIMELINE_SUMMARIES = {
    "assessment_opened": lambda p: "Assessment opened",
    "evidence_viewed": lambda p: f"Viewed {p.get('artifact_id')}",
    "search_performed": lambda p: f"Searched: {p.get('query')}",
    "ai_prompt_submitted": lambda p: "Submitted an AI prompt",
    "ai_response_received": lambda p: "AI responded",
    "ai_suggestion_dispositioned": lambda p: f"Dispositioned AI suggestion: {p.get('option_id')}",
    "tool_invoked": lambda p: f"Tool invoked: {p.get('tool')}",
    "hypothesis_recorded": lambda p: f"Hypothesis recorded: {p.get('hypothesis_id')}",
    "hypothesis_revised": lambda p: f"Hypothesis revised: {p.get('hypothesis_id')}",
    "test_executed": lambda p: f"Test executed: {p.get('test_id')} -> {p.get('status')}",
    "decision_recorded": lambda p: f"Decision: {p.get('action')}",
    "final_submission": lambda p: "Final submission recorded",
    "technical_error": lambda p: f"Technical error: {p.get('message')}",
}


def _criterion_labels(scenario) -> dict[str, str]:
    labels = {c["criterion_id"]: c["label"] for c in scenario.criteria}
    labels.update(_BACKEND_CRITERION_LABELS)
    return labels


def _session_block(session: Session, events: list[dict]) -> dict:
    return {
        "session_id": session.id,
        "scenario_id": session.scenario_id,
        "scenario_version": session.scenario_version,
        "display_name": session.display_name,
        "completed": session.status in ("submitted", "graded"),
        "elapsed_active_ms": max((e.get("elapsed_active_ms", 0) for e in events), default=0),
    }


def _timeline(events: list[dict]) -> list[dict]:
    return [
        {
            "sequence": e["sequence"],
            "event_type": e["event_type"],
            "occurred_at": e["occurred_at"],
            "summary": _TIMELINE_SUMMARIES.get(e["event_type"], lambda p: e["event_type"])(e["payload"]),
        }
        for e in events
    ]


def _hypotheses(events: list[dict]) -> list[dict]:
    return [
        {
            "version": e["payload"].get("version"),
            "hypothesis_id": e["payload"].get("hypothesis_id"),
            "confidence": e["payload"].get("confidence"),
            "trigger_evidence_ids": e["payload"].get("trigger_evidence_ids", []),
        }
        for e in events
        if e["event_type"] in ("hypothesis_recorded", "hypothesis_revised")
    ]


def _deterministic_block(rows: list[ScoringResult], labels: dict[str, str]) -> dict:
    summary = next((r for r in rows if r.layer == "deterministic" and r.criterion_id == "_layer1_summary"), None)
    criteria = []
    for r in rows:
        if r.layer != "deterministic" or r.criterion_id == "_layer1_summary":
            continue
        detail = json.loads(r.detail)
        criteria.append(
            {
                "criterion_id": r.criterion_id,
                "label": labels.get(r.criterion_id, r.criterion_id),
                "points": r.value,
                "status": detail.get("status"),
                "evidence_refs": json.loads(r.evidence_refs),
            }
        )
    total = summary.value if summary else sum(r.value for r in rows if r.layer == "deterministic")
    max_value = summary.max_value if summary else None
    return {"total": total, "max": max_value, "criteria": criteria}


def _ai_analysis_block(rows: list[ScoringResult]) -> dict:
    dimensions = []
    narrative = {"text": "", "scored": False}
    for r in rows:
        if r.layer != "llm_rubric" or r.criterion_id == "interview_questions":
            continue
        detail = json.loads(r.detail)
        if r.criterion_id == "thinking_style":
            narrative = {"text": detail.get("text", ""), "scored": False}
            continue
        dimensions.append(
            {
                "dimension": r.dimension,
                "score": r.value,
                "scale": 5,
                "consensus": detail.get("consensus"),
                "flagged": detail.get("flagged", False),
                "justification": detail.get("justification", ""),
                "cited_event_ids": json.loads(r.evidence_refs),
                "graders": detail.get("graders", []),
            }
        )
    return {
        "label": "AI analysis — model opinion, human review required",
        "dimensions": dimensions,
        "narrative": narrative,
    }


def _context_indices_block(rows: list[ScoringResult]) -> dict:
    indices = []
    ai_used = True
    for r in rows:
        if r.layer != "context_index":
            continue
        detail = json.loads(r.detail)
        available = detail.get("available", True)
        entry = {
            "index_id": r.criterion_id,
            "value": r.value if available else None,
            "formula": detail.get("formula"),
            "inputs": detail.get("inputs"),
            "available": available,
        }
        if detail.get("reason"):
            entry["reason"] = detail["reason"]
        indices.append(entry)
        if "ai_used" in detail:
            ai_used = detail["ai_used"]
    return {"scored": False, "indices": indices, "ai_used": ai_used}


def _interview_questions(rows: list[ScoringResult]) -> list[str]:
    row = next((r for r in rows if r.layer == "llm_rubric" and r.criterion_id == "interview_questions"), None)
    return json.loads(row.detail).get("questions", []) if row else []


async def build_report(db, session_id: str) -> dict:
    session = await db.get(Session, session_id)
    if session is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)

    events = await load_events(db, session_id)
    scenario = get_scenario(session.scenario_id, session.scenario_version)
    labels = _criterion_labels(scenario)

    result = await db.execute(select(ScoringResult).where(ScoringResult.session_id == session_id))
    rows = result.scalars().all()

    return {
        "session": _session_block(session, events),
        "timeline": _timeline(events),
        "hypotheses": _hypotheses(events),
        "scores": {
            "deterministic": _deterministic_block(rows, labels),
            "ai_analysis": _ai_analysis_block(rows),
            "context_indices": _context_indices_block(rows),
        },
        "interview_questions": _interview_questions(rows),
        "notices": scenario.definition.get("notices", {}),
    }
