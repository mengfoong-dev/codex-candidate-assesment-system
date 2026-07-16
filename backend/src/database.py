"""Async SQLAlchemy engine/session + per-session write lock.

Concurrency (Codex HIGH finding #5): sequence allocation and the submit compare-and-set must be
serialized per session so two concurrent requests can't both grade a session or collide on
(session_id, sequence). For a single-process demo an in-process asyncio.Lock per session is the
smallest thing that is correct; the DB unique constraint is the hard backstop underneath it.
"""
import asyncio
from collections import defaultdict

from sqlalchemy import MetaData
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from src.config import get_settings

settings = get_settings()

engine = create_async_engine(settings.database_url, future=True)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

# Stable, explicit constraint names (fastapi-best-practices convention) — makes constraints
# greppable and migrations predictable if this ever moves to Alembic/Postgres.
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


async def get_db():
    """FastAPI dependency: one AsyncSession per request, always closed."""
    async with AsyncSessionLocal() as session:
        yield session


# ponytail: in-process per-session lock. Correct for one Uvicorn process (the demo). If the
# backend ever runs multi-process on Postgres, swap for `SELECT ... FOR UPDATE` on the session
# row or `BEGIN IMMEDIATE` on SQLite. Dict access here never awaits, so it's race-free on the loop.
_session_locks: dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)


def get_session_lock(session_id: str) -> asyncio.Lock:
    """Return the write lock for a session; hold it around sequence-alloc and submit-CAS."""
    return _session_locks[session_id]
