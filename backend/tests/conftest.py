"""Pytest fixtures shared by every domain's tests.

Test DB isolation: point DATABASE_URL at a throwaway temp SQLite file BEFORE any `src` import (so
the module-level engine binds to it), then drop+create+seed the schema fresh for each test.
"""
import os
import tempfile

# Must run before importing anything under src (database.py builds the engine at import time).
_TMPDIR = tempfile.mkdtemp(prefix="vibeproof-test-")
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{_TMPDIR}/test.db"

import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402


@pytest_asyncio.fixture
async def app():
    from src.database import AsyncSessionLocal, Base, engine
    from src.main import create_app
    from src.registry import seed_scenarios

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as db:
        await seed_scenarios(db)
    return create_app()


@pytest_asyncio.fixture
async def client(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest_asyncio.fixture
async def new_session(client):
    """A freshly created active session; returns the POST /api/sessions response body."""
    resp = await client.post("/api/sessions", json={"display_name": "Test Candidate"})
    assert resp.status_code == 201, resp.text
    return resp.json()
