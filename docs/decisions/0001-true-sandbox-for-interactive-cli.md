# ADR 0001 — True on-disk sandbox for the interactive session (opt-in override of D006)

- **Status:** Accepted (2026-07-17)
- **Scope:** the interactive session path (`tools/run-interactive-simulation.ps1`) only. The web MVP default is unchanged.
- **Partially supersedes (opt-in):** decision **D006** — "Virtual Workspace = DB rows; nothing ever executes."

## Context

The candidate flow is: **Godot room (WebGL) → a terminal/workspace panel → the candidate prompts
the in-app AI agent (Simulation Engine) to create/debug code → backend streams the reply over SSE
and the AI edits code → the Evaluation Engine grades it.**

Under D006 the "workspace" is `session_files` DB rows, the AI's `write_file` upserts a row, and
"running a test" is a scripted table lookup (plus a static string check). Nothing runs. That is
correct for the assessment's default, but it means the grader never sees the code actually work.

The ask: make the interactive session a **true sandbox** — real files, real modifications, and
**real execution** of the validation tests against the candidate/AI-edited code.

Key facts that shaped the design:

- The `homepage_latency` fix is **behavioral**: three independent `await`s run sequentially and
  should run via `Promise.all`. This compiles fine both ways, so `tsc` cannot tell them apart — a
  genuine pass/fail needs a test that observes concurrency at runtime.
- Local toolchain: Node 22 + npm/npx present; no Deno.

## Decision

Add a **filesystem workspace backend**, selected by `WORKSPACE_BACKEND=fs` (default `db`), used only
by the interactive session. When enabled:

1. **Real files.** `create_session` materializes the seed into a per-session directory under a
   sandbox root (`src/workspace/sandbox.py::materialize`).
2. **Real modifications.** `write_file` lands the edit as a real file on disk *and* keeps the DB row
   as a mirror, so the read APIs / evaluation / Proof Replay are unchanged.
3. **Real execution.** `run test` runs `vitest run -t <test_id>` in the session dir
   (`sandbox.run_tests`). The result carries `scripted: false`.
4. **Hidden grading harness.** The vitest test + tsconfig live in
   `data/workspaces/homepage_latency/.harness/`, which is **absent from `_manifest.json`**, so it
   never seeds into `session_files` or `list_files` — the candidate/AI can't read the test that
   grades them. A deterministic concurrency count (not a timer) distinguishes sequential (max
   in-flight = 1 → fail) from `Promise.all` (= 3 → pass).

### Where the frontend fits (Godot terminal)

Godot does **not** run code; it is a client that calls the backend and shows results:

| Godot panel | Backend endpoint |
|---|---|
| File list | `GET /sessions/{id}/files` |
| Code view (AI edits arrive as `file_updated`) | `GET /sessions/{id}/files/{path}` |
| AI chat (streamed) | `POST /sessions/{id}/messages` (SSE `token` events) |
| "Run test" → output box | `POST /sessions/{id}/tests/{test_id}` → `status` + real vitest `actual_result` |

The "terminal" is a **UI panel**, not a real shell. (Caveat: Godot has no native SSE client, so the
streamed chat needs a manual chunked-read `HTTPClient` loop or an SSE→WebSocket bridge; the non-stream
calls work with plain `HTTPRequest`.)

### Bounded scope — NOT arbitrary execution

This stays inside the product's non-goals (`mvp-scope.md`: "no arbitrary candidate-repository
execution"). The candidate edits the seeded files and runs the **defined** validation tests only;
there is no shell, no free command execution, no editing outside the sandbox dir. This is the
brief's "adapt with verification" proof moment, not a coding test.

### Isolation / security model

Local interactive tool running the developer's own AI/hand edits, so the ceiling is: dedicated
per-session directory, path-contained writes (no `../` escapes — `sandbox._safe_path`), a hard
wall-clock timeout, and captured+truncated, force-UTF-8 output. A single shared `node_modules` at
the sandbox root is discovered by every session dir via Node's native upward module resolution
(install once, not per session).

**Not** done (deliberately): container/seccomp/VM isolation, network egress blocking.

## Consequences

- Web MVP behavior is **byte-identical** unless `WORKSPACE_BACKEND=fs`; every change is behind
  `sandbox.enabled()`. Existing db-mode tests pass unchanged.
- First session per machine pays a one-time `npm install` (~10s); later sessions/test runs are ~2.5s.
- The DB mirror is authoritative for the read APIs; a **hand-edit made directly on disk** (outside
  `write_file`) is seen by execution but not by the read APIs until re-written through the tool.

## Open item — real candidates at scale

The temp-dir + subprocess model is right for the **local** interactive tool. If real candidates
execute code **server-side** (the Godot terminal wired to a hosted backend), that is the untrusted-
execution threat model and needs stronger isolation: Node 22 `--permission` flags, or a gVisor /
Firecracker microVM, or a hosted sandbox (E2B / Modal). Decide this before any public deployment;
`isolated-vm` was considered and rejected (maintenance-mode + it cannot run a TS-project + test
runner — it is a single-snippet evaluator).

## Alternatives considered

- **Files only, no execution** — rejected: the ask was explicitly real execution.
- **Replace DB rows app-wide** — rejected: largest blast radius, changes production behavior.
- **`tsc --noEmit` as the test** — rejected: blind to the behavioral (latency) bug.
