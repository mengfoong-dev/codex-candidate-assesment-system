# ADR 0001 — True on-disk sandbox for the interactive CLI (opt-in override of D006)

- **Status:** Accepted (2026-07-17)
- **Scope:** `tools/run-interactive-simulation.ps1` and its backend path only. The web MVP is unchanged.
- **Supersedes (partially, opt-in):** decision **D006** — "Virtual Workspace = DB rows; nothing ever executes."

## Context

The interactive CLI drives the same FastAPI app the web MVP uses. Under D006 the "workspace" is
`session_files` DB rows, the AI's `write_file` upserts a row, and "running a test" is a scripted
table lookup (plus one static string check, `rewrite_check.py`). Nothing runs.

The request: make the interactive session a **true sandbox** — real files, real modifications, and
**real execution** of the validation tests against the candidate/AI-edited code.

Key facts that shaped the design:

- The `homepage_latency` fix is **behavioral**: three independent `await`s run sequentially and
  should run via `Promise.all`. This compiles fine both ways, so `tsc` cannot tell them apart — a
  genuine pass/fail needs a test that observes concurrency at runtime.
- The seed workspace declared `vitest`/`tsc` scripts but shipped **no** `tsconfig`, tests, or
  `node_modules`. "Real execution" therefore required authoring a real, runnable harness.
- Local toolchain: Node v22.21.0 + npm/npx present; no Deno.

## Decision

Add a **filesystem workspace backend**, selected by `WORKSPACE_BACKEND=fs` (default `db`), used only
by the CLI. When enabled:

1. **Real files.** `create_session` materializes the seed into a per-session directory under a
   sandbox root (`src/workspace/sandbox.py::materialize`).
2. **Real modifications.** `write_file` lands the edit as a real file on disk *and* keeps the DB row
   as a mirror, so the read APIs / evaluation / Proof Replay are unchanged.
3. **Real execution.** `run test` runs `vitest run -t <test_id>` in the session dir
   (`sandbox.run_tests`). The result carries `scripted: false`.
4. **Hidden grading harness.** The vitest test + tsconfig live in `data/workspaces/<scenario>/.harness/`,
   which is **absent from `_manifest.json`**, so it never seeds into `session_files` or `list_files` —
   the candidate/AI can't read the test that grades them. A deterministic concurrency count (not a
   timer) distinguishes sequential (max in-flight = 1 → fail) from `Promise.all` (= 3 → pass).

### Isolation / security model

Local developer tool running the developer's own AI/hand edits, so the ceiling is: dedicated
per-session directory, path-contained writes (no `../` escapes — `sandbox._safe_path`), a hard
wall-clock timeout, and captured+truncated, force-UTF-8 output. A single shared `node_modules` at the
sandbox root is discovered by every session dir via Node's native upward module resolution (install
once, not per session).

**Not** done (deliberately): container/seccomp/VM isolation, network egress blocking. Overkill for a
single-user local CLI.

## Consequences

- Web MVP behavior is **byte-identical** unless `WORKSPACE_BACKEND=fs`; every change is behind
  `sandbox.enabled()`. Existing tests (db mode) pass unchanged.
- First session per machine pays a one-time `npm install` (~10s); later sessions/test runs are ~2.5s.
- The DB mirror is authoritative for the read APIs; a **hand-edit made directly on disk** (outside
  `write_file`) is seen by execution but not by the read APIs until re-written through the tool.

## Alternatives considered

- **Files only, no execution** — rejected: the request was explicitly real execution.
- **Replace DB rows app-wide** — rejected: largest blast radius, changes production behavior for a
  3-day hackathon.
- **`tsc --noEmit` as the test** — rejected: blind to the behavioral (latency) bug.

## Upgrade path

If this ever runs untrusted candidate code server-side: Node 22 `--permission`
(`--allow-fs-read/-write` scoped to the session dir, network off by default), or a gVisor /
Firecracker microVM sandbox (per the code-execution-sandbox landscape — Modal/E2B/Fly.io).
