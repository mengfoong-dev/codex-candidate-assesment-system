# Continue — v1.0.0 Cohere live-flow migration

## Last action

Completed the live five-turn Cohere candidate session after removing the unsupported
`thinking={"type":"disabled"}` request field. The exact runner completed with exit code 0,
including `read_file`, `write_file`, two passing scripted tests, a graded report, seven Cohere
rubric dimensions, and Layer 3 indices. Focused backend tests passed (24 tests), and the complete
backend suite passed (60 tests).

## Next action

Run the documented deployed proxy health, Sam, and workspace-assistant smoke checks with a rotated
key. Separately, add an explicit provider-disable switch if the final-state scenario must be fully
offline.

## Why

The candidate API, SSE stream, sandbox tool loop, five-turn cutoff, deterministic scoring, and real
five-turn Cohere-plus-panel session are verified. The remaining work is deployed-proxy verification
and, if required, an explicit offline mode for the final-state scenario.

## Open threads

- `backend/scripts/run_final_state_simulation.py` is untracked even though the final-state docs reference it; review and commit it separately if it is intentional.
- Uncommitted files at handoff: `docs/hackathon/codex-usage/sessions.csv` (session log), `backend/uv.lock`, and `backend/src/vibeproof_backend.egg-info/` (generated local artifacts).

## Do not

- Do **not** add credentials to tracked files, the handoff, or shell history.
- Do **not** reintroduce assistant `tool_plan` on a Cohere tool-result follow-up; tool document `data` must remain serialized JSON.
- Do **not** turn Groq/NIM back into active graders; they remain opt-in outage fallback only.
- Do **not** commit generated egg-info or alter unrelated working-tree files while completing live acceptance.
