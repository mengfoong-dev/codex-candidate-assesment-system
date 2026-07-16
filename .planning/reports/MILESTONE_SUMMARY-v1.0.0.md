# Milestone Summary v1.0.0: Cohere Command A+ Live-Flow Migration

## Overview

This milestone makes Cohere Command A+ (`command-a-plus-05-2026`) the active
model for every live LLM path: the candidate simulation, senior/office proxy,
workspace assistant, and rubric panel. It removes Anthropic from active backend
and proxy setup. Groq and NVIDIA NIM remain integrated solely as an explicitly
enabled grading fallback.

The migration preserves the candidate-facing contracts: simulation Server-Sent
Events, tool-call budget, persisted event records, token accounting, report
shape, CORS, and the human-review safeguards.

## Architecture

| Component | Primary provider and protocol | Failure behavior |
| --- | --- | --- |
| Candidate simulation | Cohere Chat V2 streaming with function tools | Emits the existing `llm_unavailable` SSE/error-event path. |
| Senior and workspace-assistant proxy | Cohere `POST /v2/chat` | Returns sanitized provider errors; `/health` reports `provider: cohere`. |
| Rubric panel | Cohere Chat V2 structured JSON, one grader per dimension | Reports `consensus: "single"`; Groq/NIM are considered only when the Cohere panel is wholly unavailable and fallback is enabled. |
| Deterministic scoring | Existing local evaluator | Continues to run regardless of LLM availability. |

## Phases

1. Replaced the Anthropic simulation adapter with a Cohere V2 streaming adapter
   and translated streamed text, function-call deltas, tool results, and usage
   into the existing neutral turn loop.
2. Replaced active proxy provider selection with Cohere `/v2/chat` for both
   proxy routes while preserving prompts, response shape, CORS, and health.
3. Made Cohere the primary rubric grader, preserving provider provenance and
   constraining Groq/NIM to `AI_PANEL_FALLBACK_ENABLED=true` outages.
4. Updated local/Railway configuration templates and operational documentation.
5. Added adapter, panel, proxy, and integration coverage around the Cohere wire
   contracts and retained final-state regression coverage.

## Decisions

- Default to `COHERE_MODEL=command-a-plus-05-2026` in backend and proxy.
- Use Cohere V2 `strict_tools` and V2 assistant/tool message round trips so
  Virtual Workspace writes remain provider-correct and auditable.
- Use Cohere JSON Schema structured output for scores, narrative, and questions
  instead of parsing unstructured prose.
- Leave grading fallback disabled by default. Fallback is operational recovery,
  not a second active panel or a consensus participant.
- Keep secrets outside tracked files and Railway command history; configure
  production values through secret-variable UIs.

## Requirements

| Requirement | Delivered evidence |
| --- | --- |
| Cohere is active in all live LLM flows | Simulation adapter, proxy server, and panel configuration use Cohere model/key settings. |
| Simulation contracts are preserved | SSE, token accounting, event persistence, file writes, tool cap, outage behavior, and no-network injection seam remain covered. |
| Fallback is opt-in and provenance-aware | `AI_PANEL_FALLBACK_ENABLED` gates Groq/NIM; primary results record single-Cohere consensus. |
| Operators can configure safely | `.env.example` files and Cohere runtime documentation document local and Railway setup without keys. |

## Tech Debt and Follow-ups

- Deploy with a newly rotated `COHERE_API_KEY`, then run one authenticated Sam
  request and one workspace-assistant request against the deployed proxy.
- The final-state driver is a no-key deterministic scenario. Keep live Cohere
  credentials unset for that driver so it remains offline.
- Generated local `vibeproof_backend.egg-info/` should remain uncommitted.

## Getting Started

1. Copy `backend/.env.example` to ignored `backend/.env` and set
   `COHERE_API_KEY`; retain the default Command A+ model unless an operator has
   an approved override.
2. Set `COHERE_API_KEY`, optional `COHERE_MODEL`, and `ALLOWED_ORIGINS` in the
   Railway proxy service variable UI.
3. Run `cd backend; python -m pytest -q` and
   `cd apps/senior-proxy; npm test` before deployment.
4. See `docs/backend/COHERE_RUNTIME.md` for configuration and fallback details.
