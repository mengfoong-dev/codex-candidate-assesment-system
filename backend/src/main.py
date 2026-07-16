"""FastAPI app factory: middleware (CORS, error envelope, request logging — no auth per B-decisions),
router wiring, and startup that creates the schema and seeds the scenario idempotently."""
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from src import models  # noqa: F401 — import registers all tables on Base.metadata
from src.config import get_settings
from src.database import AsyncSessionLocal, Base, engine
from src.exceptions import register_exception_handlers
from src.registry import seed_scenarios

# Domain routers (each owned by an implementer; each declares full paths, e.g. /sessions/{id}/events).
from src.evaluation.router import router as evaluation_router
from src.chat.router import router as chat_router
from src.events.router import router as events_router
from src.scenarios.router import router as scenarios_router
from src.sessions.router import router as sessions_router
from src.simulation.router import router as simulation_router
from src.workspace.router import router as workspace_router

logger = logging.getLogger("vibeproof")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Hackathon: create schema at startup (Alembic deferred, brief 03). Seed is idempotent.
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as db:
        await seed_scenarios(db)
    logger.info("VibeProof backend ready")
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="VibeProof Backend", version="1.0.0", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def _log_requests(request: Request, call_next):
        started = time.perf_counter()
        response = await call_next(request)
        elapsed_ms = (time.perf_counter() - started) * 1000
        logger.info("%s %s -> %s (%.0f ms)", request.method, request.url.path, response.status_code, elapsed_ms)
        return response

    register_exception_handlers(app)

    for router in (
        scenarios_router,
        sessions_router,
        events_router,
        chat_router,
        workspace_router,
        simulation_router,
        evaluation_router,
    ):
        app.include_router(router, prefix="/api")

    return app


app = create_app()
