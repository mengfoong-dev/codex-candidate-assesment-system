# Final-State Backend Simulation Flow

> **Current handoff:** The complete backend state is summarized in
> [FINAL-STATE.md](FINAL-STATE.md). This document is the repeatable isolated-database/API verification flow;
> `FINAL-STATE-TEST-RESULT.md` records its observed outcome and the separate live-provider probe.

## Purpose

This repeatable validation has three layers:

1. `backend/tests/test_simulation.py` drives the real FastAPI message endpoint,
   HTTP/SSE serialization, temporary SQLite database, event log, Virtual
   Workspace, and scoring-facing records. It uses a complete Cohere V2 stream
   double only at the external provider boundary.
2. `backend/scripts/run_final_state_simulation.py` drives a candidate's full
   evidence-to-submission-to-report scenario through HTTPX ASGI transport and a temporary SQLite
   database. Submission invokes the configured rubric panel, so this driver can make live Cohere
   requests when `backend/.env` contains a key.
3. `backend/tests/test_interactive_session.py` drives the five-turn terminal runner through the
   same session, SSE, workspace, scoring, and report endpoints consumed by the TSX frontend.

Neither test path starts a server, accesses a production database, or executes candidate code.
The endpoint tests use a provider-boundary double. The final-state driver does not require an LLM
credential to complete, but it is not an offline command when a local Cohere key is configured.

## Commands

Run from the repository root in PowerShell. The endpoint suite uses its external-provider double
and is the provider-isolated verification path:

```powershell
cd backend
uv run python -m pytest tests/test_simulation.py -q
```

For the complete backend suite, use `uv run pytest -q`; the current observed result is 60 passing
tests. Run the final-state scenario separately:

```powershell
uv run python scripts/run_final_state_simulation.py
```

It creates an isolated temporary database but reads `backend/.env` through application Settings.
Empty provider variables in the process are treated as absent, so they do not override configured
`.env` keys. The observed 2026-07-16 run therefore called Cohere and returned three AI analysis
dimensions. Treat the command as a live-panel scenario until an explicit panel-disable switch is
implemented.

The interactive human runner is intentionally a separate live command because it reads the ignored
local `COHERE_API_KEY`:

```powershell
.\tools\run-interactive-simulation.ps1
```

For a live provider smoke check, ask the coding agent to read the seeded
`src/homepage_orchestrator.ts` file. The expected SSE order contains one or more `token` events,
then `tool_use`, then terminal `done`. Command A+ tool results are returned as serialized JSON
documents; if strict generation returns `INVALID_TOOL_GENERATION` before output, the backend retries
the same request once with non-strict tools.

## Simulation endpoint contract: `tests/test_simulation.py`

| Scenario | Real behavior asserted |
| --- | --- |
| Candidate asks for a latency fix | Token SSE events, tool-use SSE event, file update, exact persisted usage totals, and one persisted AI response. |
| One provider turn requests two tools | Both tool events share a turn ID and result in one final AI response. |
| Provider exceeds the eight-call budget | The ninth call is rejected before invocation and the response still concludes. |
| Provider outage or absent key | The endpoint emits a safe `llm_unavailable` message, persists a technical-error event, and never fabricates an AI response or exposes provider headers/body. |
| Five-turn cutoff | A sixth prompt produces `candidate_turn_limit_reached`, never calls the model, and is excluded from scoring evidence. |
| Submitted or unknown session | The endpoint returns HTTP 409 or HTTP 404 without starting a stream. |
| Hidden scenario data | The system prompt excludes scoring and root-cause keys. |
| Model configuration | Command A+ is accepted and legacy/blank model identifiers are rejected. |
| Cohere V2 streamed function call | Text, JSON argument deltas, tool-call ID/name, usage, and strict read/write tools are translated into neutral turn records. The request omits the `thinking` setting because Command A+ rejects it. A streamed call is authoritative even when Command A+ labels the terminal event `COMPLETE`. |
| Cohere V2 tool-result follow-up | The next request contains the assistant call and matching `tool` document payload with structured tool data. |

The stream double mirrors Cohere's external event boundary; assertions inspect
the endpoint's actual SSE output and persisted database state, not calls to the
double itself.

## Interactive five-turn flow: `tests/test_interactive_session.py`

| Scenario | Real behavior asserted |
| --- | --- |
| Scenario → chat exchange | The candidate-safe title, role, and problem brief render before prompt 1; each later prompt is requested only after the previous SSE stream has completed. |
| Agent sandbox edit | A streamed `write_file` tool call emits `file_updated`, persists the AI-owned workspace content, then completes the five-turn session and three-layer report. |
| Completion | Prompt input stops at turn five; scripted checks, final submission, and result retrieval use the public HTTP contract. |

## Final-state candidate flow

| Step | API action | Required assertion |
| --- | --- | --- |
| 1 | POST `/api/sessions` | A Homepage Latency session is created with HTTP 201 and active status. |
| 2 | GET `/api/sessions/{id}` | The initial snapshot reports active status. |
| 3 | GET files and `src/homepage_orchestrator.ts` | The seeded Virtual Workspace contains the expected source file and content. |
| 4 | POST an `evidence_viewed` event for `forged_artifact` | The registry rejects unapproved evidence with HTTP 422. |
| 5 | POST three approved evidence views | Metrics, trace, and orchestration evidence are accepted with HTTP 201. |
| 6 | POST configured scripted tests | Correctness regression and p95 latency validations pass. |
| 7 | POST the supported final conclusion | The session becomes graded. |
| 8 | GET `/api/sessions/{id}/report` | Proof Replay returns deterministic 60/70 with provenance and notices. |
| 9 | POST the submission again | The lifecycle guard rejects the duplicate with HTTP 409. |

## Expected deterministic score

The driver deliberately does not send an AI message. There is no AI suggestion
to accept, reject, or verify, so `verification_discipline` is excluded rather
than penalised. The other six applicable criteria are met, yielding 60/70.

The latest observed command output, including the current live-panel caveat, is recorded in
`FINAL-STATE-TEST-RESULT.md`.
