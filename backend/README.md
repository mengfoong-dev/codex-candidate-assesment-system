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
  chat/          POST /chat (candidate prompting MVP, thin AI relay)
  workspace/     files listing + scripted test results
  simulation/    SSE chat (Cohere Command A+ + workspace file tools)
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

## API docs and peer access

The running API exposes Swagger UI at `/docs`, ReDoc at `/redoc`, and its OpenAPI document at
`/openapi.json`. The endpoint contract is in
[docs/backend/00-api-contract.md](../docs/backend/00-api-contract.md).

To share a local backend with teammates on the same private network, start Uvicorn with
`--host 0.0.0.0`, configure their exact browser origins in `CORS_ORIGINS`, and share
`http://<host-lan-ip>:8000/docs` plus `http://<host-lan-ip>:8000/api`. Follow the full,
security-conscious setup and troubleshooting steps in
[API access guide](../docs/backend/API_ACCESS.md).

This MVP has no authentication. Keep shared instances on a trusted private network; CORS is
not an access-control mechanism and this service must not be publicly exposed as-is.

Scoring layers stay provenance-separated per decisions D006/D007/D009: Layer 1 deterministic
(scored, cites event IDs), Layer 2 LLM rubric (labeled AI analysis), Layer 3 context indices
(computed, never scored).

See [Cohere runtime configuration](../docs/backend/COHERE_RUNTIME.md) for the live-provider,
fallback, local, and Railway setup.

## Interactive five-turn candidate simulation

Add a newly rotated `COHERE_API_KEY` to the ignored `backend/.env`, then run this
single command from the repository root:

```powershell
.\tools\run-interactive-simulation.ps1
```

It creates an isolated sandbox session, accepts exactly five candidate prompts,
renders the scenario and each streamed agent/sandbox event before accepting the next prompt,
runs scripted checks for the remediation you submit, and prints the Layer 1 deterministic score,
Layer 2 Cohere rubric, and Layer 3 context indices. The same POST/SSE contract is ready for the
teammate-owned TSX frontend: [frontend stream handoff](../docs/backend/00-api-contract.md#frontend-flow-tsx-handoff).
