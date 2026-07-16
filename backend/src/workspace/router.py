"""Virtual Workspace endpoints: file listing/content + scripted test execution."""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.database import get_db
from src.exceptions import AppError
from src.models import Session
from src.registry import get_scenario
from src.workspace.service import get_file, list_files, run_scripted_test

router = APIRouter(tags=["workspace"])


class RunTestIn(BaseModel):
    remediation_id: str


async def _require_session(db, session_id: str) -> None:
    """Existence-only check for the read-only file endpoints (no later locked write in-request,
    so an ORM-hydrated load would be harmless here — kept column-only anyway for one consistent
    pattern across this router)."""
    row = (await db.execute(select(Session.id).where(Session.id == session_id))).first()
    if row is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)


async def _scenario_ref_or_404(db, session_id: str) -> tuple[str, str]:
    """Column-only lookup — never hydrates a Session ORM object into this request's identity map.
    run_scripted_test's append_event re-loads the Session via db.get() under its per-session lock
    to check status == "active"; pre-loading the full row here would let that lock-protected
    re-check see a stale cached object instead of re-querying (Codex HIGH finding #5 — same bug
    fixed in sessions/service.py and events/router.py)."""
    result = await db.execute(
        select(Session.scenario_id, Session.scenario_version).where(Session.id == session_id)
    )
    row = result.first()
    if row is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    return row.scenario_id, row.scenario_version


@router.get("/sessions/{session_id}/files")
async def get_files(session_id: str, db: AsyncSession = Depends(get_db)):
    await _require_session(db, session_id)
    return await list_files(db, session_id)


@router.get("/sessions/{session_id}/files/{file_path:path}")
async def get_file_content(session_id: str, file_path: str, db: AsyncSession = Depends(get_db)):
    await _require_session(db, session_id)
    return await get_file(db, session_id, file_path)


@router.post("/sessions/{session_id}/tests/{test_id}")
async def post_test(session_id: str, test_id: str, body: RunTestIn, db: AsyncSession = Depends(get_db)):
    scenario_id, scenario_version = await _scenario_ref_or_404(db, session_id)
    scenario = get_scenario(scenario_id, scenario_version)
    return await run_scripted_test(
        db, session_id=session_id, scenario=scenario, test_id=test_id, remediation_id=body.remediation_id
    )
