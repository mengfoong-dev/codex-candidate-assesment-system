# VibeProof Backend - Final State

**Updated:** 2026-07-17, Asia/Singapore
**Status:** Backend implementation, automated verification, and the live five-turn
Cohere-plus-panel acceptance are complete. The final-state driver uses an isolated
temporary database but invokes the configured Cohere rubric panel when `backend/.env`
contains a key.

This document is the current backend handoff for the candidate-session flow. It supersedes
the earlier Anthropic and two-active-vendor descriptions in this file.

## Delivered commits

- `14979fd feat(simulation): add five-turn interactive SSE flow`
- `2fdc78c docs(milestone): record interactive flow verification`

## Live architecture

| Layer | Active behavior |
| --- | --- |
| Candidate simulation | Cohere Command A+ (`command-a-plus-05-2026`) streams text and strict `read_file`/`write_file` tool calls through `POST /api/sessions/{id}/messages`. The request omits the unsupported `thinking` setting; non-text blocks are ignored by the adapter. An `INVALID_TOOL_GENERATION` pre-output failure retries once with non-strict tools. |
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

Final-state API scenario:

```powershell
cd backend
uv run python scripts/run_final_state_simulation.py
```

This command creates an isolated temporary SQLite database and never executes candidate
code. It is **not provider-isolated**: Settings load `backend/.env`, and blank environment
variables do not suppress configured provider keys. Run it only when live Cohere rubric
calls are acceptable. An explicit panel-disable switch is still needed for a fully offline
final-state scenario.

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

- `cd backend; uv run pytest -q` completed with **60 passed in 21.33s** on 2026-07-17.
- `cd backend; uv run python -m pytest tests/test_simulation.py -q` completed with
  **15 passed in 3.52s**. These endpoint tests use a complete Cohere V2 stream double only
  at the external-provider boundary.
- `tests/test_simulation.py` verifies the real FastAPI/SSE endpoint, persisted events, token usage,
  tool budget, safe errors, and fifth-turn enforcement using a provider-boundary double.
- `tests/test_interactive_session.py` drives the same public session, SSE, workspace, scoring, and
  report APIs used by the TSX client. It proves sequential prompt exchanges, a persisted sandbox
  edit, the cutoff, and the three-layer handoff.
- The final-state API scenario completed with a graded session, deterministic 60/70, three AI
  analysis dimensions, six context indices, and the forged-artifact (422) and duplicate-submit
  (409) guards. Its current live-panel behavior is documented below rather than treated as an
  offline test.

The detailed repeatable procedure is in [FINAL-STATE-TEST-FLOW.md](FINAL-STATE-TEST-FLOW.md);
the observed outcomes and the remaining live acceptance condition are in
[FINAL-STATE-TEST-RESULT.md](FINAL-STATE-TEST-RESULT.md).

## Remaining operational acceptance

The live acceptance completed on 2026-07-16: five prompts streamed successfully, including a
`read_file` and a `write_file` sandbox action; both scripted validations passed; and the Layer
1/2/3 report was retrieved. See [FINAL-STATE-TEST-RESULT.md](FINAL-STATE-TEST-RESULT.md) for the
observed result. A separate provider-disable configuration is still needed if the final-state
driver must become fully offline; blank provider environment variables are currently overridden by
values in `backend/.env`.
