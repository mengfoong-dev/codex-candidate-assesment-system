# Final-State Backend Simulation Flow

## Purpose

This repeatable validation has three layers:

1. `backend/tests/test_simulation.py` drives the real FastAPI message endpoint,
   HTTP/SSE serialization, temporary SQLite database, event log, Virtual
   Workspace, and scoring-facing records. It uses a complete Cohere V2 stream
   double only at the external provider boundary.
2. `backend/scripts/run_final_state_simulation.py` drives a candidate's full
   evidence-to-submission-to-report scenario through HTTPX ASGI transport.
3. `backend/tests/test_interactive_session.py` drives the five-turn terminal runner through the
   same session, SSE, workspace, scoring, and report endpoints consumed by the TSX frontend.

Neither layer starts a server, accesses a production database, executes
candidate code, or requires an LLM credential.

## Commands

Run from the repository root in PowerShell. Explicitly blank all provider keys
for the process so a developer's local `.env` cannot cause a live request.

```powershell
cd backend
$env:COHERE_API_KEY = ''
$env:GROQ_API_KEY = ''
$env:NIM_API_KEY = ''
python -m pytest tests/test_simulation.py -q
python scripts/run_final_state_simulation.py
```

The final-state driver also clears Groq/NIM for its process. Cohere is the
primary provider after this milestone, so the invoking command must explicitly
leave `COHERE_API_KEY` blank as shown above.

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
| Cohere V2 streamed function call | Text, JSON argument deltas, tool-call ID/name, usage, strict read/write tools, and disabled thinking are translated into neutral turn records. A streamed call is authoritative even when Command A+ labels the terminal event `COMPLETE`. |
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

The latest observed command output is recorded in
`FINAL-STATE-TEST-RESULT.md`.
