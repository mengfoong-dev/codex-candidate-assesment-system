# VibeProof Backend

FastAPI backend for the VibeProof Incident Room web workspace. Structure follows
[fastapi-best-practices](https://github.com/zhanymkanov/fastapi-best-practices): domain packages
under `src/`, each with its own `router.py` / `schemas.py` / `service.py`; global concerns
(`config`, `database`, `models`, `registry`, `schemas`, `exceptions`, `main`) at the `src/` root.

## Layout

```
src/
  main.py        app factory, middleware, router wiring, startup (create schema + seed)
  config.py      pydantic-settings Settings (env-driven)
  database.py    async SQLAlchemy engine/session, Base, per-session write lock
  models.py      the 5 tables (scenarios, sessions, events, session_files, scoring_results)
  registry.py    FROZEN scenario registry — loads the JSON, exposes ID sets + candidate-safe view
  schemas.py     event envelope + typed per-event payload models (the anti-forgery contract)
  exceptions.py  {"error":{code,message}} envelope + handlers
  scenarios/     GET /api/scenarios (candidate-safe list)
  sessions/      create, snapshot, submit  (session lifecycle)
  events/        POST /events  (typed, validated, append-only, concurrency-safe)
  workspace/     files listing + scripted test results
  simulation/    SSE chat (Anthropic Sonnet + workspace file tools)
  evaluation/    3-layer scoring + Proof Replay report
data/scenarios/  homepage_latency_v1.json (byte-identical to apps/incident-room copy)
tests/           golden-fixture + contract + concurrency tests
```

## Run

```bash
cd backend
python -m venv .venv && .venv/Scripts/activate    # Windows; use source .venv/bin/activate on *nix
pip install -e ".[dev]"
cp .env.example .env        # fill in keys; engines degrade gracefully without them
uvicorn src.main:app --reload
# API docs (frontend handoff): http://localhost:8000/docs
pytest
```

Scoring layers stay provenance-separated per decisions D006/D007/D009: Layer 1 deterministic
(scored, cites event IDs), Layer 2 LLM rubric (labeled AI analysis), Layer 3 context indices
(computed, never scored).
