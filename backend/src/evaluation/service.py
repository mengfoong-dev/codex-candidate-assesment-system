"""Evaluation Engine orchestrator — runs once, called by sessions.submit right after
`event_log.submit_session` records `final_submission` and flips status to "submitted".

Codex HIGH finding #4 (the brief's original diagram handed sync functions to asyncio.gather, which
only accepts awaitables and would TypeError): `rule_grade` and `compute_indices` are pure,
synchronous functions — called directly, in order (indices needs Layer 1's normalized Q as input).
Only `rubric_panel` is async; its 14 vendor calls fan out internally via asyncio.gather.

Unexpected failures are NOT caught here — they propagate so the caller (sessions.submit) can catch
them and mark the session `manual_review` instead of `graded`. A degraded panel (one or both
vendors down) is NOT a failure: `rubric_panel` already handles that gracefully by omitting rows, so
this function still writes whatever it has and completes normally.
"""
import json

from sqlalchemy import delete

from src.event_log import load_events
from src.exceptions import AppError
from src.models import ScoringResult, Session
from src.registry import get_scenario

from src.evaluation.indices import compute_indices
from src.evaluation.panel import rubric_panel
from src.evaluation.rules import rule_grade


def _extract_submission(events: list[dict]) -> dict:
    submissions = [e for e in events if e["event_type"] == "final_submission"]
    if not submissions:
        raise AppError("no_submission", "Cannot grade a session with no final_submission event", 500)
    return submissions[-1]["payload"]


def _deterministic_rows(session_id: str, layer1) -> list[ScoringResult]:
    rows = [
        ScoringResult(
            session_id=session_id,
            layer="deterministic",
            criterion_id=c.criterion_id,
            dimension=c.dimension,
            value=c.points,
            max_value=c.max_value,
            evidence_refs=json.dumps(c.evidence_refs),
            grader_label="rules_v1",
            rubric_version=None,
            detail=json.dumps({"kind": c.kind, "status": c.status}),
        )
        for c in layer1.criteria
    ]
    # Summary row so the report can show total/max/Q without re-deriving them from the criteria rows.
    rows.append(
        ScoringResult(
            session_id=session_id,
            layer="deterministic",
            criterion_id="_layer1_summary",
            dimension=None,
            value=layer1.total,
            max_value=layer1.positive_points_available,
            evidence_refs="[]",
            grader_label="rules_v1",
            rubric_version=None,
            detail=json.dumps({"normalized_q": layer1.normalized_q}),
        )
    )
    return rows


def _panel_rows(session_id: str, panel_rows: list[dict]) -> list[ScoringResult]:
    rows: list[ScoringResult] = []
    for row in panel_rows:
        criterion_id = row["dimension"]
        if criterion_id == "interview_questions":
            rows.append(
                ScoringResult(
                    session_id=session_id,
                    layer="llm_rubric",
                    criterion_id="interview_questions",
                    dimension=None,
                    value=0.0,
                    max_value=None,
                    evidence_refs="[]",
                    grader_label="panel_v1",
                    rubric_version=None,
                    detail=json.dumps({"questions": row.get("questions", [])}),
                )
            )
        elif row.get("scored") is False:  # thinking_style narrative
            rows.append(
                ScoringResult(
                    session_id=session_id,
                    layer="llm_rubric",
                    criterion_id=criterion_id,
                    dimension=criterion_id,
                    value=0.0,
                    max_value=None,
                    evidence_refs="[]",
                    grader_label="panel_v1",
                    rubric_version=row.get("rubric_version"),
                    detail=json.dumps({"text": row.get("text", "")}),
                )
            )
        else:  # a scored rubric dimension
            rows.append(
                ScoringResult(
                    session_id=session_id,
                    layer="llm_rubric",
                    criterion_id=criterion_id,
                    dimension=criterion_id,
                    value=row["score"],
                    max_value=5.0,
                    evidence_refs=json.dumps(row.get("cited_event_ids", [])),
                    grader_label="panel_v1",
                    rubric_version=row.get("rubric_version"),
                    detail=json.dumps(
                        {
                            "justification": row.get("justification"),
                            "graders": row.get("graders"),
                            "flagged": row.get("flagged"),
                            "consensus": row.get("consensus"),
                        }
                    ),
                )
            )
    return rows


def _index_rows(session_id: str, indices: list[dict]) -> list[ScoringResult]:
    rows = []
    for idx in indices:
        detail = {"formula": idx["formula"], "inputs": idx["inputs"], "available": idx["available"]}
        if idx.get("reason") is not None:
            detail["reason"] = idx["reason"]
        if "ai_used" in idx:
            detail["ai_used"] = idx["ai_used"]
        rows.append(
            ScoringResult(
                session_id=session_id,
                layer="context_index",
                criterion_id=idx["index_id"],
                dimension=None,
                value=idx["value"] if idx["value"] is not None else 0.0,
                max_value=None,
                evidence_refs="[]",
                grader_label="indices_v1",
                rubric_version=None,
                detail=json.dumps(detail),
            )
        )
    return rows


async def run_evaluation(db, session_id: str) -> None:
    session = await db.get(Session, session_id)
    if session is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)

    events = await load_events(db, session_id)
    submission = _extract_submission(events)
    scenario = get_scenario(session.scenario_id, session.scenario_version)

    layer1 = rule_grade(events, submission, scenario)                    # pure, synchronous
    indices = compute_indices(events, layer1.normalized_q, scenario)     # pure, synchronous
    panel_rows = await rubric_panel(events, submission, scenario, layer1=layer1)  # async fan-out inside

    # Re-grade rewrites only these rows (models.py): clear any prior scoring_results for this session.
    await db.execute(delete(ScoringResult).where(ScoringResult.session_id == session_id))

    rows = _deterministic_rows(session_id, layer1) + _panel_rows(session_id, panel_rows) + _index_rows(session_id, indices)
    for row in rows:
        db.add(row)

    session.status = "graded"
    await db.commit()
