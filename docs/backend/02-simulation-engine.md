# Backend Brief 02 — Simulation Engine

> **For the executing agent:** the candidate-facing AI assistant — "ChatGPT but recorded". One Cohere Chat V2 client, a small tool loop, SSE out, events in. No agent framework.

Depends on: briefs 00 (SSE + envelope), 03 (session_files, events). Consumed by: brief 01 (its events feed grading).

## What it is

A service invoked by `POST /api/sessions/{id}/messages`. It:

1. Records `ai_prompt_submitted` (payload: prompt text, referenced context IDs if the frontend sent any).
2. Assembles context: system prompt + candidate-safe scenario brief + Virtual Workspace file listing + chat history (derived from prior `ai_prompt_submitted`/`ai_response_received` events, in sequence order).
3. Streams a Cohere Command A+ response with a three-tool loop.
4. Emits SSE events (`token`, `tool_use`, `file_updated`, `done`, `error`) per the contract in brief 00.
5. Records `ai_response_received` with `payload.usage.input_tokens/output_tokens` from the API response and the model ID as `model_label`.

## Model

Cohere Command A+ (default: `command-a-plus-05-2026`; override only with `COHERE_MODEL`). Streaming uses Cohere Chat V2 tool use. `SIM_MAX_TOKENS` (default 2048) and `SIM_TEMPERATURE` remain bounded cost and behavior controls, not assessment criteria.

## Tools (the whole "codex" surface)

All three operate on `session_files` rows for this session only:

| Tool | Behavior |
|---|---|
| `list_files()` | paths + sources |
| `read_file(path)` | content or a not-found error string |
| `write_file(path, content)` | upsert with `source='ai'`; emits SSE `file_updated`; also records the write inside `ai_response_received.payload.files_written` |

Tool-loop budget: max 8 tool invocations per message (env `SIM_MAX_TOOL_CALLS`); on hitting the cap the model is told to conclude. No delete tool, no execute tool, no network tool — the Virtual Workspace never executes anything (D006).

## System prompt boundaries (assessment integrity)

The system prompt must:

- describe the assistant as a general engineering copilot inside the candidate's workspace;
- include ONLY the candidate-safe scenario view — **never** `root_cause`, `relevant_artifact_ids`, scoring config, or scripted-test result tables (same redaction function as the API, brief 03);
- not coach toward the answer beyond what any real assistant would do with the same evidence — the assistant may reason about whatever the candidate pastes or asks, exactly like real-world AI use; the assessment measures how the *candidate* directs and verifies it (D002).

The assistant genuinely knowing-but-hiding the answer is impossible if the answer is never in its context — redaction, not instruction, is the mechanism.

## Failure handling

- Anthropic call fails → SSE `error` event (`llm_unavailable`), record `technical_error` (component `simulation_engine`, `recoverable: true`, and `excluded_criterion_ids` for AI-dependent rules), candidate continues with evidence panels; grading later excludes AI-dependent criteria (mvp-scope failure policy: never penalize a platform outage).
- Mid-stream disconnect by the client → abort the API call, still record `ai_response_received` with `status: "aborted"` and whatever usage is known.

## Definition of done

- Full round trip: prompt → streamed tokens → file written by tool → both events stored with usage integers → file visible via `GET files`.
- Redaction test: system prompt content provably contains no hidden scenario keys.
- Tool-cap test: 9th tool call is refused and the response still concludes.
- Outage test: with a fake failing client, the endpoint emits the `error` SSE event and the `technical_error` event row exists.
