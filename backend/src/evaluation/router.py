"""Evaluation Engine router. Owns the read-side of grading: GET /sessions/{id}/report and
POST /sessions/{id}/email-report. POST /submit lives in the sessions router (it owns the
active->submitted transition); it calls `evaluation.service.run_evaluation` directly once
`event_log.submit_session` has recorded final_submission — the Evaluation Engine doesn't expose
its own /submit endpoint.
"""
import re

import anyio
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from src.config import get_settings
from src.database import get_db
from src.exceptions import AppError
from src.models import Session

from src.evaluation.report import build_report
from src.notifications import send_report_email

router = APIRouter(tags=["evaluation"])

# Minimal shape check only. ponytail: swap to pydantic EmailStr if email-validator ever lands as a dep.
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class EmailReportIn(BaseModel):
    email: str


# ponytail: in-process once-guard so re-fetching /report can't re-email the same session. A resend
# after a backend restart is harmless for the single-process demo (mirrors the in-process lock in
# database.py). Swap for a session column if this ever runs multi-process.
_emailed_sessions: set[str] = set()


async def _require_gradable(db, session_id: str) -> Session:
    """Shared precondition for the report endpoints: exists + submitted + not stuck in manual review.
    Extracted so the 404/409/503 contract can't drift between get_report and email_report."""
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
    return session


@router.get("/sessions/{session_id}/report")
async def get_report(session_id: str, db=Depends(get_db)):
    session = await _require_gradable(db, session_id)
    report = await build_report(db, session_id)
    await _maybe_email_report(session, report)  # flow finale: emails the candidate on first fetch
    return report


async def _maybe_email_report(session: Session, report: dict) -> None:
    """Best-effort: on the first report fetch after grading, email it to the candidate at the address
    the session was opened with (display_name). Unlike POST /email-report this NEVER raises — viewing
    results must render whether or not mail is configured or delivery succeeds. Once-guarded so a
    re-fetch can't resend."""
    if session.id in _emailed_sessions:
        return
    settings = get_settings()
    to = (session.display_name or "").strip()
    if not (settings.email_smtp_host and settings.email_address and _EMAIL_RE.match(to)):
        return  # not configured, or display_name isn't a real email (e.g. "candidate"/"Anonymous")
    try:
        await anyio.to_thread.run_sync(send_report_email, to, report)
        _emailed_sessions.add(session.id)  # mark only on success so a transient failure can retry
    except Exception:
        pass  # best-effort; POST /email-report remains the manual retry path


@router.post("/sessions/{session_id}/email-report")
async def email_report(session_id: str, body: EmailReportIn, db=Depends(get_db)):
    to = body.email.strip()
    if not _EMAIL_RE.match(to):
        raise AppError("invalid_email", "Not a valid email address", 422)
    settings = get_settings()
    if not (settings.email_smtp_host and settings.email_address):
        raise AppError("email_not_configured", "Email delivery is not configured", 503)
    await _require_gradable(db, session_id)
    report = await build_report(db, session_id)
    # smtplib is blocking; run it off the event loop. Any failure degrades to 502 without mutating
    # state — email is best-effort delivery, never part of the grading transaction.
    try:
        await anyio.to_thread.run_sync(send_report_email, to, report)
    except Exception as exc:
        raise AppError("email_send_failed", "Could not send the report email", 502) from exc
    return {"sent": True, "to": to}
