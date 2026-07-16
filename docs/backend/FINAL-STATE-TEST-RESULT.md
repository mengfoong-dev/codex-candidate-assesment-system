# Final-State Backend Simulation Result

> **Current handoff:** [FINAL-STATE.md](FINAL-STATE.md) summarizes the deployed backend contract.
> This document records the automated and live-probe evidence; the reproducible commands are in
> [FINAL-STATE-TEST-FLOW.md](FINAL-STATE-TEST-FLOW.md).

## Status

PASS - executed locally on 2026-07-16, Asia/Singapore. The automated suite uses
provider-boundary doubles, so it does not expose credentials or depend on provider quota.

## Simulation endpoint contract

Command:

```powershell
cd backend
$env:COHERE_API_KEY = ''
$env:GROQ_API_KEY = ''
$env:NIM_API_KEY = ''
python -m pytest tests/test_simulation.py -q
```

Observed output after the tool-round-trip and strict-generation recovery hardening:
**60 passed in 13.42s**.

| Coverage group | Observed result |
| --- | --- |
| SSE, file-write, usage, and event persistence | Pass: the happy-path test confirmed the response stream and persisted totals agree. |
| Multi-tool and tool-cap loop | Pass: two tool calls share one response; the ninth invocation is refused and the response concludes. |
| Cohere failure paths | Pass: both provider failure and missing key produce `llm_unavailable` without a fabricated AI response. |
| Session and prompt safeguards | Pass: submitted/unknown session guards and hidden-scenario redaction are preserved. |
| Command A+ configuration | Pass: `command-a-plus-05-2026` is accepted; legacy and blank identifiers are rejected. |
| Cohere V2 adapter | Pass: streamed text, split JSON arguments, tool calls, token usage, strict read/write workspace tools, disabled thinking, assistant turn, and tool document round trip are reconstructed correctly. The frontend lists sandbox files through its deterministic files API. |
| Interactive five-turn flow | Pass: scenario renders before prompt one, prompts and agent SSE replies alternate, a streamed sandbox edit persists, and scoring completes. |
| Server cutoff and proxy streaming | Pass: a sixth prompt cannot reach the model; SSE exposes no-cache/no-buffering headers. |
| Cohere failure containment | Pass: raw provider details cannot reach the SSE error or technical-error event. |

## Live Cohere observation

An initial five-turn live run reached `POST /v2/chat` successfully after the
strict-tool correction, but exposed two provider-compatibility defects: Command A+ consumed the
bounded response in default thinking blocks, and the rubric sent `json_schema` plus unsupported
numeric ranges. Those findings are now covered and fixed by the automated suite: both flows send
`thinking={"type":"disabled"}`, and the rubric uses valid JSON object mode with application-level
shape/range validation. Further diagnosis isolated the simulation follow-up failure: Command A+ rejects
an echoed `tool_plan`, but accepts an assistant `tool_calls` message followed by a `tool` document whose
`data` is serialized JSON. The adapter now follows that model-specific round trip. It also treats
streamed tool calls as authoritative because Command A+ can label their terminal event `COMPLETE`, and
retries an explicit pre-output `INVALID_TOOL_GENERATION` once with non-strict tools. A live temporary-
database FastAPI request emitted tokens, `tool_use` for `read_file` on
`src/homepage_orchestrator.ts`, and terminal `done` after two Cohere 200 responses. A complete
five-turn live acceptance plus panel run remains to be captured when sufficient Cohere trial quota is
available.

## Final-state candidate scenario

Command:

```powershell
cd backend
$env:COHERE_API_KEY = ''
$env:GROQ_API_KEY = ''
$env:NIM_API_KEY = ''
python scripts/run_final_state_simulation.py
```

Observed result:

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
| AI rubric dimensions | 0 | Pass: the intentional no-key path preserves deterministic grading only |
| Context indices returned | 6 | Pass |
| Required notices | human_review, limitations, navigation | Pass |
| Forged artifact guard | HTTP 422 | Pass |
| Duplicate-submit guard | HTTP 409 | Pass |

## Interpretation

This is a real in-process backend scenario, not a unit assertion over mock
calls: it creates a session, reads the workspace, records evidence, runs the
configured validations, submits a candidate conclusion, and reads the report.
The Cohere-specific endpoint suite complements it by exercising the real
streaming/tool-loop contract with a network boundary double. Together they show
that the Cohere migration preserves the no-key deterministic path and the
provider-aware simulation path without live credentials.
