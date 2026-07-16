# VibeProof Backend - Final State

**Updated:** 2026-07-16, Asia/Singapore
**Status:** Backend implementation and automated verification complete. The final live
five-turn Cohere-plus-panel acceptance remains pending available provider trial quota.

This document is the current backend handoff for the candidate-session flow. It supersedes
the earlier Anthropic and two-active-vendor descriptions in this file.

## Delivered commits

- `14979fd feat(simulation): add five-turn interactive SSE flow`
- `2fdc78c docs(milestone): record interactive flow verification`

## Live architecture

| Layer | Active behavior |
| --- | --- |
| Candidate simulation | Cohere Command A+ (`command-a-plus-05-2026`) streams text and strict `read_file`/`write_file` tool calls through `POST /api/sessions/{id}/messages`. Thinking is disabled so the bounded output budget is available to the candidate. An `INVALID_TOOL_GENERATION` pre-output failure retries once with non-strict tools. |
| Sandbox inventory | The TSX client receives seeded files from `POST /api/sessions` and refreshes them through `GET /api/sessions/{id}/files`. Listing is deterministic; it is not delegated to Cohere. |
| Five-turn lifecycle | The server permits exactly five candidate prompts. Each prompt must finish its SSE stream before the next begins. A sixth prompt emits `candidate_turn_limit_reached` without reaching the model or scoring log. |
| Scoring layer 1 | Deterministic event-based rules, always available. |
| Scoring layer 2 | One Cohere rubric grader per dimension, recorded with `consensus: "single"`. Groq/NIM run only when `AI_PANEL_FALLBACK_ENABLED=true` and the full Cohere panel is unavailable. |
| Scoring layer 3 | Deterministic context indices, never used as an employment decision. |

The virtual workspace remains session-scoped database data. No generated file is executed.

## Candidate and frontend flow

1. `POST /api/sessions` returns the candidate-safe scenario and seeded sandbox files. Render the
   scenario problem and workspace before chat begins.
2. For turns 1 through 5, `POST /api/sessions/{id}/messages` with `Accept: text/event-stream`.
   Render `token`, `tool_use`, `file_updated`, `done`, and `error` events incrementally.
3. On `file_updated`, refetch the file using `GET /api/sessions/{id}/files/{path}` and display the
   sandbox edit.
4. After turn 5, disable prompt input, collect the candidate conclusion, run selected scripted
   validations, submit with `POST /submit`, then fetch `GET /report` to render all three layers.

The implementation-ready TSX event types and stream parser are in
[00-api-contract.md](00-api-contract.md#frontend-flow-tsx-handoff).

## Local commands

Interactive human-driven run:

```powershell
.\tools\run-interactive-simulation.ps1
```

Equivalent command:

```powershell
cd backend
uv run python scripts/run_interactive_candidate_session.py
```

The runner prints the scenario, accepts one prompt after each completed agent stream, displays
sandbox tool/file activity, stops after the fifth turn, and prints the submitted three-layer report.
It reads credentials from the ignored `backend/.env`; never place a key in this document or shell
history.

## Verification evidence

- `cd backend; uv run pytest -q` completed with **60 passed**.
- `tests/test_simulation.py` verifies the real FastAPI/SSE endpoint, persisted events, token usage,
  tool budget, safe errors, and fifth-turn enforcement using a provider-boundary double.
- `tests/test_interactive_session.py` drives the same public session, SSE, workspace, scoring, and
  report APIs used by the TSX client. It proves sequential prompt exchanges, a persisted sandbox
  edit, the cutoff, and the three-layer handoff.
- A live temporary-database FastAPI probe returned token events, `tool_use` for `read_file` on
  `src/homepage_orchestrator.ts`, and terminal `done` after the serialized tool-result follow-up.

The detailed repeatable procedure is in [FINAL-STATE-TEST-FLOW.md](FINAL-STATE-TEST-FLOW.md);
the observed outcomes and the remaining live acceptance condition are in
[FINAL-STATE-TEST-RESULT.md](FINAL-STATE-TEST-RESULT.md).

## Remaining operational acceptance

Run one complete live session with five human prompts and the Cohere panel once trial quota is
available. Confirm visible streamed feedback, at least one sandbox edit, fifth-turn cutoff, and the
Layer 1/2/3 report. The backend safely retries one `INVALID_TOOL_GENERATION` pre-output provider
failure with non-strict tools and emits a sanitized SSE error if Cohere remains unavailable; it does
not expose headers, trace IDs, or credentials.
