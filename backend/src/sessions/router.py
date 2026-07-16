"""Session lifecycle endpoints: create, snapshot, and final submission."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.database import get_db
from src.schemas import FinalSubmissionPayload
from src.sessions.schemas import CreateSessionIn, CreateSessionOut, SessionSnapshotOut
from src.sessions.service import create_session, get_session_snapshot, submit_final_submission

router = APIRouter(tags=["sessions"])


@router.post("/sessions", status_code=201, response_model=CreateSessionOut)
async def post_session(body: CreateSessionIn, db: AsyncSession = Depends(get_db)):
    return await create_session(db, display_name=body.display_name, scenario_id=body.scenario_id)


@router.get("/sessions/{session_id}", response_model=SessionSnapshotOut)
async def get_session(session_id: str, db: AsyncSession = Depends(get_db)):
    return await get_session_snapshot(db, session_id)


@router.post("/sessions/{session_id}/submit")
async def post_submit(session_id: str, body: FinalSubmissionPayload, db: AsyncSession = Depends(get_db)):
    return await submit_final_submission(db, session_id=session_id, submission=body.model_dump())
