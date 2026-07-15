# Backend Brief 03 — Database & Session Lifecycle

> **For the executing agent:** SQLite via SQLAlchemy 2.x async (`aiosqlite`). Keep models in one module; no migrations tool (Alembic deferred — schema is created at startup for the hackathon). Everything here is deliberately boring.

Depends on: brief 00 (event envelope). Consumed by: briefs 01, 02.

## Tables

### `scenarios`

| Column | Type | Notes |
|---|---|---|
| `scenario_id` | TEXT PK (with `version`) | `homepage_latency` |
| `version` | TEXT PK | `1.0.0` |
| `definition` | JSON TEXT | full scenario document, see below |

The definition reuses the Godot plan's `homepage_latency_v1.json` structure (`docs/superpowers/plans/2026-07-15-vibeproof-incident-room-mvp.md` Task 1) with three backend extensions:

1. `seeded_files`: `[{path, content}]` — the faulty source files for the Virtual Workspace (the sequential-`await` orchestrator example).
2. `relevant_artifact_ids`: `["metrics_overview", "homepage_trace", "homepage_orchestrator"]` — the pre-tagged relevant-evidence set for the EC rule (brief 04).
3. `rubric` config for Layer 2 dimensions (brief 04).

Seeding: on startup, if the scenario row is absent, load `backend/data/scenarios/homepage_latency_v1.json` and insert. Keep IDs byte-identical with the Godot copy; they are maintained manually in sync (two files, one vocabulary).

Candidate-safe view: a function strips `root_cause`, `relevant_artifact_ids`, `results_by_remediation`, `rubric`, and scoring config before anything leaves the API.

### `sessions`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID4 |
| `scenario_id`, `scenario_version` | TEXT | FK by convention |
| `display_name` | TEXT | the "placeholder user" — no users table exists |
| `status` | TEXT | `active` → `submitted` → `graded` (or `submitted` + manual-review flag) |
| `started_at`, `submitted_at` | TEXT | ISO-8601 UTC |

### `events`

Append-only. Columns mirror the envelope: `event_id` PK, `session_id` (indexed), `sequence` INT, `scenario_id`, `scenario_version`, `event_type` (indexed), `actor`, `occurred_at`, `elapsed_active_ms`, `payload` JSON TEXT, plus `event_schema_version`.

- Unique constraint on `(session_id, sequence)`; sequence is allocated inside the same transaction as the insert.
- No UPDATE or DELETE statements exist for this table anywhere in the codebase — enforce by grep in review, not by trigger (YAGNI).

### `session_files`

| Column | Type | Notes |
|---|---|---|
| `session_id` + `path` | composite PK | |
| `content` | TEXT | |
| `source` | TEXT | `seeded` / `ai` / `user` |
| `updated_at` | TEXT | |

Created by copying `scenario.definition.seeded_files` at session creation. Mutated only by the Simulation Engine's `write_file` tool (source `ai`) or an explicit candidate file-save endpoint if the frontend adds one (source `user`).

### `scoring_results`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | |
| `session_id` | TEXT, indexed | |
| `layer` | TEXT | `deterministic` / `llm_rubric` / `context_index` |
| `criterion_id` | TEXT | rule ID, dimension ID, or index ID |
| `dimension` | TEXT NULL | assessment dimension label |
| `value`, `max_value` | REAL | points, 1–5 score, or index value |
| `evidence_refs` | JSON TEXT | cited event IDs (Layer 1 mandatory, Layer 2 cited quotes, Layer 3 inputs) |
| `grader_label` | TEXT | `rules_v1` or vendor/model string |
| `rubric_version` | TEXT | |
| `detail` | JSON TEXT | justification, formula, inputs, flags |

Written once per grading run; a re-grade (manual recovery) deletes and rewrites **only** rows for that session — never events.

## Session lifecycle (orphan-never-delete)

```text
POST /api/sessions ──► active ──(submit)──► submitted ──(grading ok)──► graded
        │                                        └─(grading failed)──► submitted + manual_review
        └─ browser reload: frontend forgets the ID and creates a NEW session.
           The old session and all its rows remain untouched, forever.
           There is no delete endpoint, no cleanup job, no cascade delete.
```

- The session ID lives in frontend JS memory only (not localStorage) — that implements the agreed "flush" semantics.
- `elapsed_active_ms` on events is reported by the frontend (its active-time clock); the backend stores it verbatim and never derives scores from it (D009).

## Relationships & hierarchy

```text
scenarios  (scenario_id, version)          ← PRIMORDIAL ROOT — most upstream
    │ 1:N
    ▼
sessions   (id UUID)                       ← aggregate root of one candidate attempt
    │ 1:N                 │ 1:N                    │ 1:N
    ▼                     ▼                        ▼
events                session_files           scoring_results
(session_id,          (session_id, path)      (id; session_id FK)
 sequence)                                        │
    ▲                                             │ cites, via evidence_refs JSON
    └─────────────── soft N:M ────────────────────┘
```

| Relationship | Cardinality | Notes |
|---|---|---|
| scenarios → sessions | 1:N | each session pins exactly one `(scenario_id, version)` |
| sessions → events | 1:N | unique `(session_id, sequence)` |
| sessions → session_files | 1:N | PK is `(session_id, path)` |
| sessions → scoring_results | 1:N | ~25 rows, written once at submit |
| scoring_results ↔ events | soft N:M | `evidence_refs` is a JSON list of event IDs, not a join table — refs are read-only audit pointers, never queried in reverse in the MVP |

- **Primordial primary key:** `scenarios (scenario_id, version)` — composite, because scenario versions must coexist without touching prior sessions' history. Everything descends from it.
- **Aggregate root per attempt:** `sessions.id`. Every per-candidate row is reached only through its session. There is intentionally **no users table** (decision B6, no auth); `sessions.display_name` is a label, not an identity. If auth ever arrives, a `users` table slots in above sessions (`users 1:N sessions`) with no other change.
- **Denormalization note:** events carry `scenario_id`/`scenario_version` copied onto every row. That is an audit stamp so the log is self-describing in isolation — not a hierarchy edge. Events belong to sessions only.
- The model is a strict tree plus one soft citation link; no true N:M join table exists anywhere.

## Definition of done

- Startup creates the schema and seeds the scenario idempotently.
- `(session_id, sequence)` uniqueness proven by a concurrent-insert test.
- Candidate-safe view test asserts hidden keys are absent.
- A grep for `UPDATE events|DELETE FROM events` returns nothing.
