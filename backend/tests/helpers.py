"""Shared test helpers (owned by the lead so no implementer collides on test infra).

The main use is crafting event-log fixtures for the Evaluation Engine tests: insert raw Event rows
in a chosen order, then run the grader over them.
"""
import json

from src.database import AsyncSessionLocal
from src.models import Event


def event_id(session_id: str, sequence: int) -> str:
    return f"{session_id}:{sequence:06d}"


async def insert_event(
    session_id: str,
    sequence: int,
    event_type: str,
    payload: dict | None = None,
    *,
    actor: str = "candidate",
    scenario_id: str = "homepage_latency",
    scenario_version: str = "1.0.0",
    elapsed_active_ms: int = 0,
) -> str:
    """Insert one Event row directly (bypasses API validation — for building grading fixtures)."""
    eid = event_id(session_id, sequence)
    async with AsyncSessionLocal() as db:
        db.add(
            Event(
                event_id=eid,
                session_id=session_id,
                sequence=sequence,
                event_schema_version="1.0.0",
                scenario_id=scenario_id,
                scenario_version=scenario_version,
                event_type=event_type,
                actor=actor,
                occurred_at=f"2026-07-16T02:{sequence:02d}:00Z",
                elapsed_active_ms=elapsed_active_ms,
                payload=json.dumps(payload or {}),
            )
        )
        await db.commit()
    return eid


async def build_log(session_id: str, events: list[tuple]) -> list[str]:
    """events = [(event_type, payload, actor?), ...] inserted with auto-incrementing sequence from 1."""
    ids = []
    for i, ev in enumerate(events, start=1):
        etype, payload = ev[0], ev[1]
        actor = ev[2] if len(ev) > 2 else "candidate"
        ids.append(await insert_event(session_id, i, etype, payload, actor=actor))
    return ids
