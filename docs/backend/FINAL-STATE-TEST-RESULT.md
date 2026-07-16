# Final-State Backend Simulation Result

> **Current handoff:** [FINAL-STATE.md](FINAL-STATE.md) summarizes the deployed backend contract.
> This document records the automated and live-probe evidence; the reproducible commands are in
> [FINAL-STATE-TEST-FLOW.md](FINAL-STATE-TEST-FLOW.md).

## Status

PASS - refreshed locally on 2026-07-17, Asia/Singapore. The full backend suite completed with
**60 passed in 21.33s**. The provider-boundary endpoint suite is isolated from credentials and
provider quota; the final-state driver is isolated from the production database but currently uses
the local Cohere configuration if one is present.

## Simulation endpoint contract

Command:

```powershell
cd backend
uv run python -m pytest tests/test_simulation.py -q
```

Observed output: **15 passed in 3.52s**.

| Coverage group | Observed result |
| --- | --- |
| SSE, file-write, usage, and event persistence | Pass: the happy-path test confirmed the response stream and persisted totals agree. |
| Multi-tool and tool-cap loop | Pass: two tool calls share one response; the ninth invocation is refused and the response concludes. |
| Cohere failure paths | Pass: both provider failure and missing key produce `llm_unavailable` without a fabricated AI response. |
| Session and prompt safeguards | Pass: submitted/unknown session guards and hidden-scenario redaction are preserved. |
| Command A+ configuration | Pass: `command-a-plus-05-2026` is accepted; legacy and blank identifiers are rejected. |
| Cohere V2 adapter | Pass: streamed text, split JSON arguments, tool calls, token usage, strict read/write workspace tools, assistant turn, and tool document round trip are reconstructed correctly. The request omits `thinking`, which Command A+ rejects. The frontend lists sandbox files through its deterministic files API. |
| Interactive five-turn flow | Pass: scenario renders before prompt one, prompts and agent SSE replies alternate, a streamed sandbox edit persists, and scoring completes. |
| Server cutoff and proxy streaming | Pass: a sixth prompt cannot reach the model; SSE exposes no-cache/no-buffering headers. |
| Cohere failure containment | Pass: raw provider details cannot reach the SSE error or technical-error event. |

## Live Cohere observation

An initial five-turn live run reached `POST /v2/chat` successfully after the
strict-tool correction, but exposed two provider-compatibility defects: Command A+ consumed the
bounded response in default thinking blocks, and the rubric sent `json_schema` plus unsupported
numeric ranges. The live provider now rejects `thinking={"type":"disabled"}` with
`INVALID_TOOL_GENERATION`, so both flows omit that setting; the adapter ignores non-text blocks and the
rubric uses valid JSON object mode with application-level shape/range validation. Further diagnosis isolated the simulation follow-up failure: Command A+ rejects
an echoed `tool_plan`, but accepts an assistant `tool_calls` message followed by a `tool` document whose
`data` is serialized JSON. The adapter now follows that model-specific round trip. It also treats
streamed tool calls as authoritative because Command A+ can label their terminal event `COMPLETE`, and
retries an explicit pre-output `INVALID_TOOL_GENERATION` once with non-strict tools. A live temporary-
database FastAPI request emitted tokens, `tool_use` for `read_file` on
`src/homepage_orchestrator.ts`, and terminal `done` after two Cohere 200 responses. The latest
final-state scenario run also reached the live rubric panel and returned three AI analysis dimensions
while preserving the deterministic 60/70 report and lifecycle guards.

## Live five-turn interactive acceptance

On 2026-07-16, `cd backend; uv run python scripts/run_interactive_candidate_session.py` completed
with five non-empty candidate prompts and a valid final submission (exit code 0; 51.7 seconds).
The first prompt read `src/homepage_orchestrator.ts`; the fourth wrote that sandbox file. Each of
the five prompt streams completed before the next prompt, and the final submission ran both scripted
checks successfully: correctness regression (12 of 12 fixtures) and p95 latency (310 ms with an
unchanged error rate).

The session reached grading and returned all three layers:

- Layer 1: `-5.0/70.0`. This scripted candidate did not create candidate-controlled evidence or
  hypothesis events, so this score is expected and does not affect the lifecycle acceptance.
- Layer 2: all seven Cohere rubric dimensions returned a single-provider score of `5.0`.
- Layer 3: context indices were returned, including `e_p: 0.0`, hypothesis convergence `0.0`,
  and raw counts showing five prompts and two sandbox tool calls.

This run is the live acceptance evidence for the Cohere streaming/tool-follow-up path and rubric
panel. It contains no credentials or provider request metadata.

## Final-state candidate scenario

Command:

```powershell
cd backend
uv run python scripts/run_final_state_simulation.py
```

Observed result: the scenario used a temporary SQLite database and completed, but application
Settings loaded the configured `backend/.env` Cohere key despite empty provider environment
variables. The run therefore made live Cohere rubric calls; it must not be described as a
no-network or intentional no-key path.

| Check | Observed value | Result |
| --- | --- | --- |
| Scenario | `homepage_latency@1.0.0` | Pass |
| Session lifecycle | `graded` | Pass |
| Virtual Workspace source verified | `src/homepage_orchestrator.ts` | Pass |
| Evidence views recorded | 3 | Pass |
| Correctness regression | 12 of 12 scripted fixtures passed | Pass |
| Homepage p95 latency | Scripted p95 is 310 ms and the error rate is unchanged | Pass |
| Deterministic score | 60/70 | Pass |
| `verification_discipline` | excluded | Pass: no AI response or disposition occurred |
| AI rubric dimensions | 3 | Pass: the configured Cohere panel returned three analysis dimensions; panel degradation did not block grading |
| Context indices returned | 6 | Pass |
| Required notices | human_review, limitations, navigation | Pass |
| Forged artifact guard | HTTP 422 | Pass |
| Duplicate-submit guard | HTTP 409 | Pass |

## Interpretation

This is a real in-process backend scenario, not a unit assertion over mock
calls: it creates a session, reads the workspace, records evidence, runs the
configured validations, submits a candidate conclusion, and reads the report.
The Cohere-specific endpoint suite complements it by exercising the real
streaming/tool-loop contract with a network boundary double. Together they verify
the provider-isolated endpoint contract and the current provider-aware scenario;
they do not yet establish a fully offline final-state driver.
