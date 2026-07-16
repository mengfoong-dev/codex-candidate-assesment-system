# VibeProof Backend MVP Design

## Status

Approved 2026-07-15 after a grilling session against `PRD.md`, `docs/product/`, `docs/decisions.md`, and `docs/assessment/evidence-and-scoring.md`. Every decision below was resolved with the backend owner; conflicts with the canonical decision log were surfaced and resolved in favor of the log (D006, D007, D009).

Terminology in this document follows `UBIQUITOUS_LANGUAGE.md`.

## Purpose

Build the FastAPI backend for the canonical VibeProof web workspace: a candidate investigates the Homepage Latency Spike scenario with evidence panels and an AI assistant, submits a conclusion, and the system produces a Proof Replay with three clearly separated scoring layers.

The backend serves the frontend team's web UI. The Godot prototype (`prototypes/godot-incident-room/`) is a separate, offline presentation experiment and shares only the scenario content and event vocabulary.

## Decisions

| # | Decision | Choice | Why |
|---|---|---|---|
| B1 | Scoring architecture | 3-layer: deterministic rules (scored) → LLM rubric (labeled) → context indices (unscored) | D007 requires deterministic-first with constrained LLM use; the layers keep provenance visible while still demoing multi-LLM grading |
| B2 | Efficiency formulas (E_p, EPI, …) | Layer 3 context, computed always, formula displayed, never scored | D009; the research literature treats efficiency as a diagnostic axis, not a competence score |
| B3 | Orchestration | Plain `asyncio.gather`; no LangGraph | Grading is embarrassingly parallel with no cycles, shared state, or mid-graph human input; a framework adds dependency risk in a 3-day window |
| B4 | Sandbox | Virtual Workspace: files are DB rows; tests return scripted results; nothing executes | D006 defers arbitrary execution; scripted results keyed by remediation follow the Godot plan's `results_by_remediation` pattern |
| B5 | Database | SQLite + SQLAlchemy async | Zero setup for teammates; ORM makes Postgres a connection-string change |
| B6 | Session lifecycle | Orphan-never-delete; session ID held in frontend memory only | Reload = fresh session, but Proof Replay requires history; "flush" = browser forgets, DB remembers |
| B7 | Chat transport | SSE via FastAPI `StreamingResponse` | One-way token streaming needs no WebSocket state management |
| B8 | Models | Simulation: Anthropic Sonnet. Grading panel: Groq + NVIDIA NIM | Multi-vendor consensus for the pitch; both grader vendors are OpenAI-compatible, so one client with a base-URL swap replaces LiteLLM |

## Architecture

```text
FastAPI routes (thin, validated by Pydantic, no business logic)
  ├─ SessionService      create session, snapshot, ingest frontend events,
  │                      run scripted tests, accept final submission
  ├─ SimulationEngine    Sonnet chat with read_file/write_file/list_files tools
  │                      against the Virtual Workspace; streams SSE; records
  │                      its own events including token usage
  └─ EvaluationEngine    runs once at final submission, in parallel:
       ├─ RuleGrader       pure function over events (11 rules, cites event IDs)
       ├─ RubricPanel      7 dimensions × 2 vendors, JSON-schema output,
       │                   median consensus, discrepancy flag
       └─ ContextIndices   pure formulas (E_p, EPI, Entropy, HC, AR)

Middleware: CORS, error envelope, request logging. No auth.
```

Layer boundaries: routes never touch models directly; engines never build HTTP responses; scoring reads only the event log and final submission — never presentation state.

## Data model (5 tables)

| Table | Purpose | Key fields |
|---|---|---|
| `scenarios` | Versioned incident package | `scenario_id`, `version`, `definition` (JSON: brief, artifacts+facts, seeded faulty files, scripted AI fallback, tests with `results_by_remediation`, submission options, rubric config, `relevant_artifact_ids` tag for EC) |
| `sessions` | One candidate attempt | `id` (UUID), `scenario_id`, `scenario_version`, `display_name`, `status` (active/submitted/graded), `started_at`, `submitted_at` |
| `events` | Append-only source of truth | frozen envelope: `event_id`, `session_id`, `sequence`, `event_type`, `actor`, `occurred_at`, `elapsed_active_ms`, `payload` JSON. Token usage lives on `ai_response_received.payload` |
| `session_files` | Virtual Workspace state | `session_id`, `path`, `content`, `source` (seeded/ai/user), `updated_at` |
| `scoring_results` | One row per criterion × layer | `session_id`, `layer` (deterministic/llm_rubric/context_index), `criterion_id`, `dimension`, `value`, `max_value`, `evidence_refs` JSON, `grader_label`, `rubric_version`, `detail` JSON |

The event envelope, event types, and all scenario IDs reuse the frozen vocabulary from `docs/superpowers/plans/2026-07-15-vibeproof-incident-room-mvp.md` and `docs/assessment/evidence-and-scoring.md`, extended with `payload.usage.input_tokens` / `output_tokens` on `ai_response_received`.

## API surface

```text
GET  /api/scenarios                          list public scenario views
POST /api/sessions                           create session (+ seeded file copies)
GET  /api/sessions/{id}                      snapshot
POST /api/sessions/{id}/events               frontend-observed events
POST /api/sessions/{id}/messages             SSE stream from Simulation Engine
GET  /api/sessions/{id}/files                Virtual Workspace listing
POST /api/sessions/{id}/tests/{test_id}      scripted test result
POST /api/sessions/{id}/submit               final submission → triggers evaluation
GET  /api/sessions/{id}/report               Proof Replay (3 layers + timeline)
```

Full request/response shapes: `docs/backend/00-api-contract.md`.

## Scoring design

Full catalog with formulas and input/output computations: `docs/backend/04-metrics-rubrics.md`. Summary:

- **Layer 1 (scored)** — 9 deterministic rules from `evidence-and-scoring.md` plus two research-promoted deterministic measures: Evidence Coverage (premature-closure detection) and Verification Discipline. Max = 80 points (negative rules subtract from the total, not the max); every point cites event IDs; the normalized total doubles as the quality input `Q` for Layer 3.
- **Layer 2 (AI analysis)** — LLM rubric panel over 7 qualitative dimensions plus one unscored thinking-style narrative. Groq + NIM grade independently; median consensus; >1.5-band discrepancy flags human review. Always labeled AI analysis, quotes events, never mixed into Layer 1 points.
- **Layer 3 (context)** — E_p, EPI, Investigation Entropy, Hypothesis Convergence, AI Reliance Ratio, and raw counts. All inputs numerical (event counts + token usage metadata + normalized Layer 1 score). Never scored, per D009.

## Failure handling

| Failure | Behavior |
|---|---|
| Grader vendor down | Skip that vendor's rows; single-vendor results marked `consensus: single`; both down → deterministic + context layers only, report flagged for manual review (D007 fallback) |
| Simulation LLM down | Chat returns an error SSE event; candidate continues with evidence panels; outage recorded as `technical_error` event; AI-dependent rules excluded from scoring (mvp-scope failure policy) |
| Submission with grading crash | Preserve events + submission; session status stays `submitted`; report endpoint returns 503 with manual-review flag — never a misleading partial score |
| SQLite write failure | 500 with error envelope; no silent in-memory fallback (backend, unlike the offline Godot build, has no reason to continue without persistence) |

## Out of scope (MVP)

Auth and accounts; real code execution; resumable sessions; recruiter dashboard UI (report is JSON; frontend renders it); multiple scenarios; proctoring; Postgres migration; employment verdicts of any kind.

## Execution briefs

Subagent-ready briefs, dependency-ordered:

1. `docs/backend/00-api-contract.md` — frozen contract, event envelope, SSE format
2. `docs/backend/03-database-sessions.md` — schema, lifecycle, seeding
3. `docs/backend/02-simulation-engine.md` — chat, tools, streaming, event capture
4. `docs/backend/01-evaluation-engine.md` — three layers, panel mechanics
5. `docs/backend/04-metrics-rubrics.md` — formulas, computations, rubric anchors, citations
