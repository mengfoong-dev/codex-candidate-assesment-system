# Backend Brief 00 — API Contract

> **For the executing agent:** this contract is frozen — the frontend team builds against it in parallel. Change a shape here only with the backend owner's sign-off, and update this file in the same commit. Base path `/api`, JSON everywhere except the SSE endpoint. FastAPI + Pydantic models; the auto-generated `/docs` page is the frontend handoff.

Terminology: `UBIQUITOUS_LANGUAGE.md`. Design rationale: `docs/superpowers/specs/2026-07-15-vibeproof-backend-mvp-design.md`.

## Conventions

For local-network peer setup, CORS configuration, and smoke tests, see [API access guide](API_ACCESS.md).

- IDs: session IDs are UUID4 strings; all scenario/artifact/hypothesis/remediation/test IDs use the frozen vocabulary from `docs/superpowers/plans/2026-07-15-vibeproof-incident-room-mvp.md` §Frozen IDs.
- Errors: every non-2xx response is `{"error": {"code": "<machine_code>", "message": "<human text>"}}`.
- No auth. CORS allows the frontend dev origin(s) via env var `CORS_ORIGINS`.
- Timestamps: ISO-8601 UTC.

## Event envelope (shared with the event log)

Every event — whether recorded by the backend or reported by the frontend — is stored in this envelope (from the Godot plan, unchanged except the usage extension):

```json
{
  "event_schema_version": "1.0.0",
  "event_id": "<session_id>:000042",
  "session_id": "…",
  "sequence": 42,
  "scenario_id": "homepage_latency",
  "scenario_version": "1.0.0",
  "event_type": "evidence_viewed",
  "actor": "candidate | system | scripted_assistant",
  "occurred_at": "2026-07-16T02:10:00Z",
  "elapsed_active_ms": 130000,
  "payload": { }
}
```

`ai_response_received.payload` additionally carries `"usage": {"input_tokens": int, "output_tokens": int}` — required for the Layer 3 indices (see brief 04).

## Endpoints

### `GET /api/scenarios`

Returns candidate-safe scenario views. **Never include** hidden fields (`root_cause`, scoring config, `relevant_artifact_ids`, `results_by_remediation`).

```json
[{"scenario_id": "homepage_latency", "version": "1.0.0", "title": "Homepage Latency Spike", "role": "software_engineer", "duration_minutes": 30}]
```

### `POST /api/sessions`

Body: `{"display_name": "Candidate A", "scenario_id": "homepage_latency"}` (both optional; defaults: `"Anonymous"`, the only scenario).

`201`:

```json
{
  "session_id": "…",
  "scenario": { "…candidate-safe view: brief, stations, artifacts, hypothesis options, submission options, notices…" },
  "files": [{"path": "src/homepage_orchestrator.ts", "source": "seeded"}]
}
```

Side effects: copies seeded faulty files into `session_files`; records `assessment_opened`.

### `GET /api/sessions/{id}`

Snapshot: session status, current hypothesis + confidence, viewed artifact IDs, file list, chat history (derived from events, in order). `404` if unknown.

### `POST /api/sessions/{id}/events`

For `decision_recorded`, the payload requires `action` and `rationale`, with optional `risk`.

Frontend-observed actions. Body: `{"event_type": "…", "payload": { }}`. The backend stamps the envelope (sequence, timestamps).

Allowed frontend-reported types (whitelist — everything else `422`): `evidence_viewed`, `hypothesis_recorded`, `hypothesis_revised`, `search_performed`, `ai_suggestion_dispositioned`, `decision_recorded`.

Backend-recorded types (rejected if the frontend sends them): `assessment_opened`, `ai_prompt_submitted`, `ai_response_received`, `test_executed`, `final_submission`, `technical_error`.

`201` returns the stored envelope. `409` if the session is already submitted.

### `POST /api/sessions/{id}/messages` — SSE

Body: `{"content": "candidate prompt text"}`. Response: `text/event-stream`:

```text
event: token         data: {"text": "…"}                      (repeats)
event: tool_use      data: {"tool": "write_file", "path": "…"}
event: file_updated  data: {"path": "…", "source": "ai"}
event: done          data: {"response_id": "…", "usage": {"input_tokens": 812, "output_tokens": 344}}
event: error         data: {"code": "llm_unavailable", "message": "…"}
```

Records `ai_prompt_submitted` before the call and `ai_response_received` (with usage) after; file writes also update `session_files`. See brief 02.

### `GET /api/sessions/{id}/files` · `GET /api/sessions/{id}/files/{path}`

Listing returns `[{path, source, updated_at}]`; single file adds `content`.

### `POST /api/sessions/{id}/tests/{test_id}`

Body: `{"remediation_id": "parallelize_confirmed_independent_calls"}`.

`200`: `{"test_id": "p95_latency", "expected_result": "…", "actual_result": "…", "status": "passed | failed | unavailable", "scripted": true}`

Always `"scripted": true` — the UI must label results as prototype simulations. Records `test_executed`.

### `POST /api/sessions/{id}/submit`

Body — the frozen `final_submission` payload fields:

```json
{
  "root_cause_id": "…", "supporting_evidence_ids": ["…"], "remediation_id": "…",
  "expected_impact_id": "…", "risk_ids": ["…"], "assumption_ids": ["…"],
  "validation_test_ids": ["…"], "rollback_id": "…", "final_confidence": 80, "rationale": "…"
}
```

Validation: all IDs must resolve against the scenario's options; `final_confidence` 0–100. `422` lists every missing/unknown field. On success: records `final_submission`, sets status `submitted`, runs the Evaluation Engine, sets `graded`. `200`: `{"session_id": "…", "status": "graded"}` (or `"submitted"` with `"grading": "failed_pending_manual_review"`).

`409` on double submit.

### `GET /api/sessions/{id}/report`

The Proof Replay. `409` until submitted; `503` + `manual_review: true` if grading failed.

```json
{
  "session": {"session_id": "…", "scenario_id": "…", "scenario_version": "…", "display_name": "…", "completed": true, "elapsed_active_ms": 0},
  "timeline": [{"sequence": 1, "event_type": "…", "occurred_at": "…", "summary": "…"}],
  "hypotheses": [{"version": 1, "hypothesis_id": "…", "confidence": 60, "trigger_evidence_ids": []}],
  "scores": {
    "deterministic": {"total": 70, "max": 80, "criteria": [{"criterion_id": "…", "label": "…", "points": 10, "status": "met|missed|excluded", "evidence_refs": ["…:000012"]}]},
    "ai_analysis": {"label": "AI analysis — model opinion, human review required", "dimensions": [{"dimension": "…", "score": 4, "scale": 5, "consensus": "median|single", "flagged": false, "justification": "…", "cited_event_ids": ["…"], "graders": [{"vendor": "groq", "model": "…", "score": 4}]}], "narrative": {"text": "…", "scored": false}},
    "context_indices": {"scored": false, "indices": [{"index_id": "e_p", "value": 61.2, "formula": "…", "inputs": {"Q": 77.8, "P_total": 9, "R_fail": 0.22}}], "ai_used": true}
  },
  "interview_questions": ["…"],
  "notices": {"human_review": "…", "limitations": "…", "navigation": "…"}
}
```

Every deterministic criterion carries `evidence_refs`; every AI dimension carries `cited_event_ids` and grader provenance; every index carries its formula and inputs — the three-layer provenance rule is visible in the payload itself.

## Definition of done

- All endpoints implemented with Pydantic request/response models visible in `/docs`.
- Whitelist enforcement on frontend-reported event types.
- Candidate-safe scenario view provably excludes hidden fields (test asserts key absence).
- Error envelope consistent across 404/409/422/500/503.
