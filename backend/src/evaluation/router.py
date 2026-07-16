"""Evaluation Engine router. Owns the read-side of grading: GET /sessions/{id}/report. POST /submit
lives in the sessions router (it owns the active->submitted transition); it calls
`evaluation.service.run_evaluation` directly once `event_log.submit_session` has recorded
final_submission — the Evaluation Engine doesn't expose its own /submit endpoint.
"""
from fastapi import APIRouter, Depends

from src.database import get_db
from src.exceptions import AppError
from src.models import Session

from src.evaluation.report import build_report

router = APIRouter(tags=["evaluation"])


@router.get("/sessions/{session_id}/report")
async def get_report(session_id: str, db=Depends(get_db)):
    session = await db.get(Session, session_id)
    if session is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    if session.status not in ("submitted", "graded"):
        raise AppError("not_submitted", "Session has not been submitted yet", 409)
    if session.manual_review:
        raise AppError(
            "manual_review_required",
            "Grading failed; results are pending manual review",
            503,
            {"manual_review": True},
        )
    return await build_report(db, session_id)
