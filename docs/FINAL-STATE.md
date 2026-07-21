# VibeProof Project - Final State

**Updated:** 2026-07-20, Asia/Singapore  
**Status:** The local Godot candidate frontend and FastAPI backend now have one verified
startup command. The launcher starts the backend on the loopback interface, waits for its
scenario endpoint to become ready, then opens the Godot Incident Room.

This is the current whole-project operational handoff. It complements, rather than replaces,
the API-specific state in [backend/FINAL-STATE.md](backend/FINAL-STATE.md).

## Delivered project state

- `tools/start-project.ps1` validates `uv`, the pinned Godot executable, and the requested
  local port before it starts either process.
- The launcher starts `uv run uvicorn src.main:app --host 127.0.0.1 --port 8000` from
  `backend/`, waits for `GET /api/scenarios` to return HTTP 200, then launches
  `apps/incident-room` in Godot.
- [STARTUP-PLAYBOOK.md](STARTUP-PLAYBOOK.md) documents prerequisites, local URLs, evidence,
  and narrowly scoped recovery steps.
- The root README and documentation index link to the one-command flow and this handoff.

## Live architecture

| Layer | Active behavior |
| --- | --- |
| Candidate frontend | Godot 4.7.1 Standard opens `apps/incident-room` as a visible desktop process. The launcher does not alter the project, import assets, or start a Web export. |
| Backend | Uvicorn runs the existing FastAPI app from `backend/src/main.py` on `127.0.0.1:8000`. Its startup lifecycle creates the configured schema and seeds scenarios. |
| Readiness gate | The launcher probes `GET /api/scenarios`, which reaches the actual application after startup seeding. Godot only starts after that route returns HTTP 200. |
| Diagnostics | Backend standard output and error are written separately under `%TEMP%` as `vibeproof-backend-8000.out.log` and `vibeproof-backend-8000.err.log`. |
| Excluded services | `apps/senior-proxy`, `apps/code-runner`, Remotion, and the Godot Web-export server remain optional and are not started. |

## Candidate and frontend flow

1. Run the startup command from the repository root.
2. The backend starts locally and becomes ready after its FastAPI lifespan completes.
3. The Godot Incident Room opens as the candidate-facing frontend.
4. Confirm the backend at `/api/scenarios` or `/docs`; complete the in-game journey manually
   when visual and interaction acceptance is required.

The startup command is intentionally local-only. It does not expose the backend to a LAN,
change the Godot project's configured API endpoints, or execute candidate code.

## Local commands

Start both required local services:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-project.ps1
```

Use a different free backend port only when the corresponding client configuration is also
updated:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-project.ps1 -BackendPort 8001
```

Verify the backend and Godot process after startup:

```powershell
(Invoke-WebRequest http://127.0.0.1:8000/api/scenarios -UseBasicParsing).StatusCode
Get-Process -Name Godot_v4.7.1-stable_win64
```

## Verification evidence

- On 2026-07-20, `tools/start-project.ps1` was run from the repository root.
- Uvicorn logged `VibeProof backend ready`, then served `GET /api/scenarios` with HTTP 200.
- A listener was observed at `127.0.0.1:8000` owned by backend process `4292`.
- A direct post-launch request to `http://127.0.0.1:8000/api/scenarios` returned HTTP `200`
  with a 158-byte response.
- Godot process `18164` (`Godot_v4.7.1-stable_win64`) was observed running after launch.

This is a real startup verification. It does not replace the existing backend test suite or a
human visual/control pass through the candidate journey.

## Remaining operational acceptance

The current startup check proves process launch and backend readiness. Before a demo or release,
open the Godot window and complete the relevant candidate journey to verify visual rendering,
keyboard controls, and the intended frontend-to-backend interaction. The launcher intentionally
does not manage shutdown or restart of processes from earlier runs.
