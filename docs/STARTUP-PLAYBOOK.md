# VibeProof Startup Playbook

Use this one command from the repository root to start the local FastAPI backend and the visible Godot Incident Room application:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-project.ps1
```

The launcher starts FastAPI at `http://127.0.0.1:8000`, waits for
`GET /api/scenarios` to return HTTP 200, and then opens the Godot app. It prints both
process IDs when ready.

## Prerequisites

- `uv` available on `PATH`.
- Backend dependencies already synced from `backend/`: `cd backend; uv sync`.
- Godot 4.7.1 Standard installed at
  `%LOCALAPPDATA%\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe`.
- Port `8000` available locally.

## Verify the running services

- Backend API: [http://127.0.0.1:8000/api/scenarios](http://127.0.0.1:8000/api/scenarios)
- API documentation: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- Frontend: a Godot Incident Room window opens and stays open.

The backend is intentionally bound to `127.0.0.1`, so this command does not expose it to
the local network.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `uv was not found` | Install `uv`, reopen PowerShell, then run `cd backend; uv sync`. |
| Godot path was not found | Install the pinned Godot 4.7.1 Standard executable at the location above. |
| Port 8000 is in use | Stop the existing local service, or use `-BackendPort 8001` and configure any client that needs the new port. |
| Backend does not become ready | Read `%TEMP%\vibeproof-backend-8000.out.log` and `%TEMP%\vibeproof-backend-8000.err.log`. |

The launcher does not start optional services: `apps/senior-proxy`, `apps/code-runner`,
Remotion, or the Godot Web-export server.
