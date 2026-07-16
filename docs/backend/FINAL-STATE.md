# VibeProof Backend — Final State (Milestone: MVP Backend Complete)

**Date:** 2026-07-16 · **Status:** ✅ Complete & verified · **On:** `main` @ `origin` (pushed)
**Layout:** [fastapi-best-practices](https://github.com/zhanymkanov/fastapi-best-practices) — domain packages under `backend/src/`.

This is the capstone for the execution briefs in `docs/backend/00`–`04`: what actually got built,
how it was verified, and what remains. Terminology follows `UBIQUITOUS_LANGUAGE.md`.

---

## 1. Milestone goal

Ship the FastAPI backend for the VibeProof Incident Room web workspace: a candidate investigates the
Homepage Latency scenario with evidence panels + an AI assistant, submits a conclusion, and the system
produces a **Proof Replay** with three provenance-separated scoring layers (D006/D007/D009). No auth
(prototype). Nothing ever executes — the Virtual Workspace is DB rows.

## 2. What shipped

Delivered by an **opus lead + 3 sonnet implementers** (coordinating agent team): the lead authored the
shared contract/foundation, then three implementers built disjoint domains against it in parallel.

```
backend/
  pyproject.toml · .env.example · .gitignore · README.md
  data/scenarios/homepage_latency_v1.json     byte-identical to apps/incident-room copy (checksum-synced)
  src/
    main.py         app factory, CORS + error + request-log middleware, startup (schema + seed)
    config.py       pydantic-settings Settings (env-driven)
    database.py     async SQLAlchemy engine/session, Base, per-session write lock
    models.py       the 5 tables
    registry.py     FROZEN scenario registry — loads JSON, ID sets, candidate-safe redaction, validation
    schemas.py      event envelope + typed per-event payload models (anti-forgery)
    event_log.py    atomic append + submit compare-and-set (the only place events are written)
    exceptions.py   {"error":{code,message}} envelope + handlers
    scenarios/      GET /api/scenarios  (candidate-safe list)
    sessions/       create · snapshot · submit  (session lifecycle)
    events/         POST /events  (typed, validated, append-only, concurrency-safe)
    workspace/      files listing + scripted test results
    simulation/     SSE chat (Anthropic Sonnet + Virtual Workspace file tools)
    evaluation/     3-layer scoring + Proof Replay report  (rules · indices · panel · report · service)
  tests/            49 tests (conftest + helpers owned centrally)
```

## 3. Architecture

```
FastAPI routes (thin, Pydantic-validated, no business logic)
  ├─ SessionService     create/seed, snapshot, submit (atomic active→submitted)
  ├─ SimulationEngine   Sonnet chat w/ read/write/list_files over the Virtual Workspace;
  │                     streams SSE; records its own events incl. aggregated token usage
  └─ EvaluationEngine   runs once at submit:
       ├─ RuleGrader      pure fn over events — canonical criterion IDs from the registry
       ├─ RubricPanel     7 dimensions × 2 vendors (Groq + NIM), median consensus, discrepancy flag
       └─ ContextIndices  pure formulas (E_p, EPI, Entropy, HC, AR) — zero-safe, never scored
Middleware: CORS · error envelope · request logging. No auth.
```

**Layer boundaries (enforced):** routes never touch models; engines never build HTTP; scoring reads
only the event log + final submission, never presentation state.

**Scoring provenance (D006/D007/D009):**
- **Layer 1 — deterministic (scored):** 9 canonical rules + `evidence_coverage` + `verification_discipline`; every point cites event IDs; normalized total = `Q` for Layer 3.
- **Layer 2 — LLM rubric (labeled AI analysis):** always labeled, quotes events, never mixed into Layer-1 points, never an employment verdict.
- **Layer 3 — context indices (never scored):** computed always, formula displayed, D009-compliant.

## 4. API surface

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/scenarios` | candidate-safe scenario list |
| POST | `/api/sessions` | create session (+ seeded workspace files) |
| GET | `/api/sessions/{id}` | snapshot (state derived from the event log) |
| POST | `/api/sessions/{id}/events` | frontend-observed events (typed, whitelisted, validated) |
| POST | `/api/sessions/{id}/messages` | SSE stream from the Simulation Engine |
| GET | `/api/sessions/{id}/files[/{path}]` | Virtual Workspace listing / file |
| POST | `/api/sessions/{id}/tests/{test_id}` | scripted test result (`scripted: true`) |
| POST | `/api/sessions/{id}/submit` | final submission → runs evaluation |
| GET | `/api/sessions/{id}/report` | Proof Replay (3 layers + timeline) |

`/docs` (FastAPI auto-docs) is the frontend contract handoff.

## 5. Data model (5 tables)

`scenarios` (composite PK `scenario_id,version`) → `sessions` (UUID aggregate root) → `events`
(append-only, unique `(session_id,sequence)`) · `session_files` (Virtual Workspace) · `scoring_results`
(one row per criterion × layer). Orphan-never-delete: reload = new session, old rows persist for Proof Replay.

## 6. Pre-implementation Codex review — all findings resolved

| # | Finding | Fix | Verified |
|---|---|---|---|
| HIGH 1 | Scoring-ID drift from frozen contract | `RuleGrader` emits IDs/points/dimensions read from `registry.criteria` (the scenario JSON) — predicates are the only backend logic | report shows canonical IDs |
| HIGH 2 | Forgeable / incomplete events | typed per-event payloads + ID validation vs scenario + state checks; restored `decision_recorded` / `tool_invoked` | forged `artifact_id` → 422 |
| HIGH 3 | Hard-coded Layer-1 max (80) | dynamic `positive_points_available` (excluded criteria drop from the denominator) | e2e max = 70 (VD excluded) |
| HIGH 4 | Non-executable async diagram | sync grade/indices called directly; only the rubric panel is awaited (gather inside it) | submit → graded, no TypeError |
| HIGH 5 | Submit/sequence races | per-session `asyncio.Lock` + atomic status compare-and-set + `populate_existing` fresh-read + DB unique constraint | double-submit → 409; 20-way concurrent events unique |
| MED | Zero-input indices (NaN) | unavailable-contract for `e_p`/`epi`/`ai_reliance` when denominators are 0 | e2e indices null, no NaN |
| MED | Tool-loop token accounting | one `ai_response_received` per candidate message; usage = sum of all provider calls; `done.usage` == persisted | simulation test asserts invariant |
| MED | Unverified model ID | `SIM_MODEL` is config with a health check; resolved label recorded per response | — |
| MED | Scenario copy sync | byte-identical JSON + `verify_scenario_sync()` checksum test | `[]` (in sync) |

## 7. Verification

- **`pytest` → 49 passed** in the shared venv (Python 3.12.10); no network — all LLM calls mocked.
- **End-to-end HTTP drive** (`create → 3× evidence → scripted test → submit → report`) with **no API keys**: session graded, deterministic 60/70, correct met-criteria, Layer 2 gracefully degraded to deterministic-only (D007), Layer 3 zero-safe, notices present, double-submit → 409, forged event → 422.

## 8. Locked decisions (design) + build-time reconciliations

Design decisions B1–B8 (see `docs/superpowers/specs/2026-07-15-vibeproof-backend-mvp-design.md`) hold as-is.
Reconciliations made during integration:
- Kept `homepage_latency_v1.json` byte-identical (checksum-synced) and moved backend-only policy
  (`relevant_artifact_ids`, seeded files, rubric) into `registry.py` as code.
- Added `text` / `files_written` to `AiResponseReceivedPayload` so `/docs` honestly reflects the payload.
- Hardened `event_log._load_session` with `populate_existing=True` (defense-in-depth for the submit race).

## 9. Not done / out of scope / next steps

- **Env keys** for live engines: `COHERE_API_KEY` (simulation and grading), plus optional `GROQ_API_KEY` / `NIM_API_KEY` only when `AI_PANEL_FALLBACK_ENABLED=true` → `backend/.env`. Engines degrade gracefully without them.
- `COHERE_MODEL` defaults to `command-a-plus-05-2026`. The simulation preserves its `SIM_MAX_TOKENS` and `SIM_TEMPERATURE` controls.
- Not implemented (deliberate): auth, real code execution, resumable sessions, Postgres migration, `"aborted"` SSE status, recruiter dashboard UI. Out of scope per the MVP design.

## 10. How to run

```bash
cd backend
python -m venv .venv && .venv/Scripts/activate     # source .venv/bin/activate on *nix
pip install -e ".[dev]"
cp .env.example .env    # fill keys (optional; engines degrade without them)
uvicorn src.main:app --reload      # /docs = frontend handoff
pytest
```

## 11. Provenance

Built 2026-07-16 (hackathon day 2). Key commits on `main`: `0c07a67` (backend feature),
`2e48bf2` (session log), `fc67b3d` (FastAPI-conventions Codex hook). Delivered via lead + 3-agent
team; the lead authored the shared foundation, implementers built scenarios/sessions/events/workspace,
the Simulation Engine, and the Evaluation Engine against it. Zero inter-agent messages — the frozen
contract held.
