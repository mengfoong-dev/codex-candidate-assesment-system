"""POST /sessions/{id}/events — frontend-reported action log."""
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.database import get_db
from src.events.service import record_frontend_event
from src.exceptions import AppError
from src.models import Session
from src.registry import get_scenario
from src.schemas import EventEnvelope, FrontendEventIn

router = APIRouter(tags=["events"])


async def _scenario_ref_or_404(db, session_id: str) -> tuple[str, str]:
    """Column-only lookup — never hydrates a Session ORM object into this request's identity map.
    append_event re-loads the Session via db.get() under its per-session lock to check
    status == "active"; if we'd ORM-loaded the row here first, that lock-protected re-check would
    see this stale cached object instead of re-querying, letting a write race past a concurrent
    submit (Codex HIGH finding #5 — see the same bug fixed in sessions/service.py)."""
    result = await db.execute(
        select(Session.scenario_id, Session.scenario_version).where(Session.id == session_id)
    )
    row = result.first()
    if row is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    return row.scenario_id, row.scenario_version


@router.post("/sessions/{session_id}/events", status_code=201, response_model=EventEnvelope)
async def post_event(session_id: str, body: FrontendEventIn, db: AsyncSession = Depends(get_db)):
    scenario_id, scenario_version = await _scenario_ref_or_404(db, session_id)
    scenario = get_scenario(scenario_id, scenario_version)
    return await record_frontend_event(
        db, session_id=session_id, scenario=scenario, event_type=body.event_type, payload=body.payload
    )
