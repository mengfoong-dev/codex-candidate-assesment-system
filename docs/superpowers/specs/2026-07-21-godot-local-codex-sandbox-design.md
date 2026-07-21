# Godot Local Codex Sandbox Design

**Status:** Approved direction; pending specification review
**Date:** 2026-07-21
**Scope:** Local, controlled demo only

## Goal

Provide one auditable local-demo path from the Godot Codex Terminal to the
simulation engine: an LLM tool call changes a persistent backend-owned
workspace, the backend runs the real Vitest suite, and the same session yields
the three-layer evaluation report.

## Decisions

- Godot calls FastAPI directly on `localhost`; it does not use the Senior
  proxy. The Senior proxy remains a separate service for Sam.
- Only an LLM `write_file` tool call may edit the candidate workspace. The
  candidate cannot type directly into the code editor.
- FastAPI is the authority for workspace contents, tool events, test outcomes,
  turn limits, and evaluation inputs. Godot renders that state.
- Errors from FastAPI, the LLM provider, tool execution, or tests appear in the
  Codex Terminal. There is no canned assistant response or local edit fallback.
- Five candidate prompts remain the default, but the backend owns and
  configures the limit.
- Local SQLite data and filesystem sandbox directories persist between launcher
  runs so a prior session can be reopened.
- Layer 2 citations are displayed using event names/titles, rather than raw
  event identifiers. Layer 3 shows its values, formula inputs, and reasons.
- The React mini client from PR #6 remains a standalone API/debug reference; it
  is not embedded in, or shipped with, the Godot demo.

## Non-goals

- Public, multi-tenant, or internet-exposed code execution.
- Browser or JavaScript sandbox state persisted in the Godot application.
- A second assistant, test-runner, or Senior-proxy route for the Codex Terminal.
- Replacing the existing Sam/Senior-proxy workflow.
- Treating a client-reported `sandbox_passed` signal as grading evidence.

## Architecture

| Component | Responsibility | Authority boundary |
| --- | --- | --- |
| Local-demo launcher | Starts FastAPI in filesystem-sandbox mode on loopback, then opens Godot with the matching URL. | Process lifecycle and local-only configuration. |
| Godot Codex Terminal | Sends prompts, consumes simulation SSE events, displays files, tests, errors, and reports. | Presentation only; no candidate-workspace writes. |
| FastAPI simulation engine | Creates/reopens sessions, invokes the LLM, emits tool and file events, applies the turn limit. | Source of truth for session state and edits. |
| Filesystem sandbox | Holds the session workspace and runs real Vitest commands against it. | Local controlled execution only. |
| Evaluation engine | Computes deterministic Layer 1, Cohere-backed Layer 2, and telemetry-derived Layer 3. | Source of truth for all score evidence. |

The existing PR #6 filesystem sandbox is reused. No new executor, browser
sandbox, React embedding, or proxy is introduced.

## Candidate flow

1. The launcher sets the local-demo configuration, starts FastAPI on
   `127.0.0.1`, waits for readiness, and opens Godot with that backend URL.
2. Godot creates a new simulation session or lists and reopens a persisted local
   session. The backend materializes its filesystem workspace when needed.
3. Godot displays the selected backend file as read-only candidate context.
4. The candidate submits a natural-language request in the Codex Terminal.
   Godot posts it to the simulation session and consumes the response stream.
5. FastAPI records prompt, provider response, tool call, and tool result events.
   A successful LLM `write_file` changes the persistent session workspace and
   emits a file-updated event.
6. Godot refetches the file after that event and displays the returned backend
   contents. It never applies assistant code locally first.
7. Godot requests a test run. FastAPI runs Vitest in the session filesystem
   sandbox, stores the authoritative result and source revision, and returns the
   status/output for terminal display.
8. On submission, Godot requests the report for that same session. The backend
   builds all scoring layers from persisted events, the backend test result, and
   its recorded source revision.

## Reliability and state rules

- Requests for one session are processed sequentially. A dependent action
  (refresh file, run tests, or submit) is enabled only after the preceding
  backend request has succeeded.
- The existing best-effort Godot queue is removed from the Codex path. It must
  not drop a disposition or code event before the backend acknowledges it.
- A failed provider request, tool call, SSE stream, file fetch, or test run is
  shown as a terminal error and leaves the last confirmed workspace state
  visible. The candidate may explicitly retry.
- The backend rejects a prompt after the configured turn limit and returns a
  terminal-visible error. Godot does not enforce a competing limit.
- A test record includes the SHA-256 source revision it tested. A later
  successful write invalidates the displayed passing state until a new backend
  test run completes for the new revision.

## Evaluation contract

### Layer 1: deterministic implementation evidence

Layer 1 uses only the FastAPI-created test result marked `scripted: false` and
the matching stored source revision. Existing Godot client signals are retained
only as non-grading presentation telemetry, if retained at all.

### Layer 2: LLM rubric evidence

The evaluator continues to score rubric dimensions through its configured LLM
provider. It must expose a clear provider/error status when unavailable rather
than substituting uncomputed reasoning. Each cited event is returned as a
display object containing its stable event ID, human-readable title, and
sequence/order. The database can retain raw IDs; Godot renders the title.

### Layer 3: behavioural telemetry evidence

Layer 3 is computed from backend-recorded candidate prompt, provider response,
tool, write, error, and test events. The report includes every index value, the
formula/inputs used, and a plain-language reason. Godot must no longer rely on
its local scripted interaction events for Layer 3 metrics.

## Local-demo configuration

| Setting | Local-demo value | Purpose |
| --- | --- | --- |
| `WORKSPACE_BACKEND` | `fs` | Enables the existing persistent filesystem sandbox. |
| `WORKSPACE_SANDBOX_ROOT` | A project-local persistent demo directory | Keeps each session workspace locally inspectable and reusable. |
| `DATABASE_URL` | A project-local persistent SQLite database | Preserves local session history and evaluation evidence. |
| `SIM_MAX_CANDIDATE_TURNS` | `5` by default | Makes the backend turn limit configurable and authoritative. |
| FastAPI bind address | `127.0.0.1` only | Prevents the developer sandbox from being network reachable. |
| Godot backend URL | The launcher-provided loopback URL | Ensures the demo targets the local simulation engine. |

Filesystem mode is forbidden for public or shared deployment until it has an
appropriate isolated execution model. This launcher is deliberately for one
trusted local developer machine.

## Acceptance evidence

The implementation is complete only when these checks pass:

1. A provider-boundary fake proves the Godot-facing simulation route consumes
   backend SSE tool and file events; the UI does not fabricate an edit.
2. A successful `write_file` produces a backend event and refetching the file
   returns byte-identical persisted contents.
3. The seeded exercise first fails real Vitest, then an LLM tool-call fix makes
   it pass with `scripted: false`.
4. A second successful write invalidates the prior test-pass display until the
   backend runs a new test against its new SHA-256 revision.
5. Provider, tool, and test failures are terminal-visible and do not cause a
   hidden local code change or canned reply.
6. The sixth candidate prompt is rejected by the backend when the configured
   limit is five.
7. The completed report shows Layer 1 evidence, Layer 2 scores with cited event
   titles and provider status, and Layer 3 values with formulas, inputs, and
   reasons.
8. Restarting the launcher allows an existing local session and its recorded
   history/workspace to be reopened.

An opt-in local Cohere smoke test may verify credentials and provider behaviour,
but it is not part of the ordinary automated test suite.

## Specification self-review

- The direct Godot-to-FastAPI boundary is explicit and excludes the Senior
  proxy from this demo path.
- Workspace mutation, testing, and scoring authorities each have one owner.
- Local persistence and loopback-only constraints are defined.
- Every user-visible reliability claim has acceptance evidence.
- React embedding and client-authoritative grading are explicitly excluded.
