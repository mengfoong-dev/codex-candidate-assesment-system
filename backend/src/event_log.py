"""The append-only event log primitive — shared by every domain, owned centrally.

Codex HIGH finding #5 (concurrency) is solved here, once:
  * `append_event` serializes sequence allocation under the per-session lock, so two concurrent
    writers can never collide on (session_id, sequence); the DB unique constraint is the backstop.
  * writes are rejected once a session leaves `active` (`require_active`), so a late event can't
    sneak in after submission and be graded.
  * `submit_session` does the write-final_submission + flip-status as one atomic compare-and-set,
    so two concurrent submits can't both grade the same session.

Every other module records events through these functions — no domain hand-inserts Event rows.
"""
import json
from datetime import datetime, timezone

from sqlalchemy import func, select

from src.database import get_session_lock
from src.exceptions import AppError
from src.models import Event, Session
from src.schemas import EventEnvelope

SCHEMA_VERSION = "1.0.0"


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def next_event_id(session_id: str, seq: int) -> str:
    return f"{session_id}:{seq:06d}"


async def _next_sequence(db, session_id: str) -> int:
    result = await db.execute(select(func.max(Event.sequence)).where(Event.session_id == session_id))
    return (result.scalar() or 0) + 1


async def _event_type_count(db, session_id: str, event_type: str) -> int:
    result = await db.execute(
        select(func.count()).select_from(Event).where(
            Event.session_id == session_id, Event.event_type == event_type
        )
    )
    return int(result.scalar_one())


async def _load_session(db, session_id: str) -> Session:
    # populate_existing=True forces a fresh SELECT even if this session_id is already in the caller's
    # identity map — so the status re-check inside the lock (finding #5) can never read a stale cached
    # row. Hardens the primitive regardless of how a caller loaded the row upstream.
    session = await db.get(Session, session_id, populate_existing=True)
    if session is None:
        raise AppError("session_not_found", f"Unknown session {session_id}", 404)
    return session


async def append_event(
    db,
    *,
    session_id: str,
    scenario_id: str,
    scenario_version: str,
    event_type: str,
    payload: dict,
    actor: str,
    elapsed_active_ms: int = 0,
    require_active: bool = True,
    max_event_type_count: tuple[str, int] | None = None,
) -> EventEnvelope:
    """Append one event atomically. Set require_active=False only for post-submission audit writes
    (e.g. a `technical_error` recorded during grading)."""
    async with get_session_lock(session_id):
        if require_active:
            session = await _load_session(db, session_id)
            if session.status != "active":
                raise AppError("session_not_active", "Session no longer accepts writes", 409)
        if max_event_type_count is not None:
            limited_event_type, maximum = max_event_type_count
            if await _event_type_count(db, session_id, limited_event_type) >= maximum:
                raise AppError(
                    "candidate_turn_limit_reached",
                    f"This assessment accepts a maximum of {maximum} candidate prompts.",
                    409,
                )
        seq = await _next_sequence(db, session_id)
        eid = next_event_id(session_id, seq)
        occurred_at = now_iso()
        db.add(
            Event(
                event_id=eid,
                session_id=session_id,
                sequence=seq,
                event_schema_version=SCHEMA_VERSION,
                scenario_id=scenario_id,
                scenario_version=scenario_version,
                event_type=event_type,
                actor=actor,
                occurred_at=occurred_at,
                elapsed_active_ms=elapsed_active_ms,
                payload=json.dumps(payload),
            )
        )
        await db.commit()
        return EventEnvelope(
            event_schema_version=SCHEMA_VERSION,
            event_id=eid,
            session_id=session_id,
            sequence=seq,
            scenario_id=scenario_id,
            scenario_version=scenario_version,
            event_type=event_type,
            actor=actor,
            occurred_at=occurred_at,
            elapsed_active_ms=elapsed_active_ms,
            payload=payload,
        )


async def submit_session(db, *, session_id: str, submission: dict) -> EventEnvelope:
    """Atomic active→submitted transition: writes final_submission + flips status under one lock.
    Raises 409 if the session is not active (double-submit)."""
    async with get_session_lock(session_id):
        session = await _load_session(db, session_id)
        if session.status != "active":
            raise AppError("already_submitted", "Session already submitted", 409)
        seq = await _next_sequence(db, session_id)
        eid = next_event_id(session_id, seq)
        occurred_at = now_iso()
        db.add(
            Event(
                event_id=eid,
                session_id=session_id,
                sequence=seq,
                event_schema_version=SCHEMA_VERSION,
                scenario_id=session.scenario_id,
                scenario_version=session.scenario_version,
                event_type="final_submission",
                actor="candidate",
                occurred_at=occurred_at,
                elapsed_active_ms=int(submission.get("elapsed_active_ms", 0)),
                payload=json.dumps(submission),
            )
        )
        session.status = "submitted"
        session.submitted_at = occurred_at
        await db.commit()
        return EventEnvelope(
            event_schema_version=SCHEMA_VERSION,
            event_id=eid,
            session_id=session_id,
            sequence=seq,
            scenario_id=session.scenario_id,
            scenario_version=session.scenario_version,
            event_type="final_submission",
            actor="candidate",
            occurred_at=occurred_at,
            elapsed_active_ms=int(submission.get("elapsed_active_ms", 0)),
            payload=submission,
        )


async def load_events(db, session_id: str) -> list[dict]:
    """Ordered snapshot of a session's events as plain dicts (payload deserialized). Grading reads
    this once at submit — never presentation state."""
    result = await db.execute(
        select(Event).where(Event.session_id == session_id).order_by(Event.sequence)
    )
    out = []
    for e in result.scalars().all():
        out.append(
            {
                "event_id": e.event_id,
                "sequence": e.sequence,
                "event_type": e.event_type,
                "actor": e.actor,
                "occurred_at": e.occurred_at,
                "elapsed_active_ms": e.elapsed_active_ms,
                "payload": json.loads(e.payload),
            }
        )
    return out
