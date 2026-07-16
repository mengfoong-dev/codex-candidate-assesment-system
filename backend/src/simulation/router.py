"""SSE chat endpoint for the Simulation Engine — the candidate-facing AI assistant.

Declares the full path (`/sessions/{id}/messages`); `main.py` mounts this router at
prefix="/api" alongside the other domain routers.
"""
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from src.database import get_db
from src.exceptions import AppError
from src.models import Session as SessionRow
from src.simulation.service import stream_candidate_message

router = APIRouter()


class MessageIn(BaseModel):
    content: str


@router.post("/sessions/{session_id}/messages")
async def post_message(session_id: str, body: MessageIn, db: AsyncSession = Depends(get_db)):
    """Pre-stream checks use the request-scoped `db` dependency; the stream itself opens its
    own session (the request-scoped one closes too early for a long-lived SSE generator)."""
    session = await db.get(SessionRow, session_id)
    if session is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    if session.status != "active":
        raise AppError("session_not_active", "Session no longer accepts messages", 409)

    return StreamingResponse(
        stream_candidate_message(
            session_id=session_id,
            scenario_id=session.scenario_id,
            scenario_version=session.scenario_version,
            content=body.content,
        ),
        media_type="text/event-stream",
    )
