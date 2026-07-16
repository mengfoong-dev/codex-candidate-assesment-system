# FastAPI API access guide

Use this guide to run the VibeProof backend once and let teammates use its APIs from the
same private network. The complete request and response contract lives in
[00-api-contract.md](00-api-contract.md); the running service also provides interactive
Swagger documentation.

## URLs to share

When the server is running, replace `<HOST_IP>` with the host machine's LAN IP address:

| Resource | Host machine | A peer on the same network |
| --- | --- | --- |
| Swagger UI | `http://localhost:8000/docs` | `http://<HOST_IP>:8000/docs` |
| ReDoc | `http://localhost:8000/redoc` | `http://<HOST_IP>:8000/redoc` |
| OpenAPI JSON | `http://localhost:8000/openapi.json` | `http://<HOST_IP>:8000/openapi.json` |
| API base URL | `http://localhost:8000/api` | `http://<HOST_IP>:8000/api` |

Swagger UI is the fastest way to inspect the real request models and try an endpoint.
Create a session first, then reuse its returned `session_id` for all session-specific calls.

## Important security boundary

The current hackathon backend intentionally has **no authentication or authorization**.
Anyone who can reach it can create sessions, write events, run scripted tests, submit a
session, and read its report. CORS only controls which browser origins may call the API; it
does **not** prevent direct requests or secure the service.

Keep the service on a trusted private network. Do not port-forward it or expose it on the
public Internet until authentication, authorization, HTTPS, and an appropriate deployment
boundary have been added.

## Host setup (Windows / PowerShell)

Run these commands on the machine that will host the API. The virtual-environment creation
and package installation are one-time setup steps.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
Copy-Item .env.example .env
```

Edit `backend/.env` and set `CORS_ORIGINS` to the **exact browser origins** used by the
frontends. It is a JSON array, not a comma-separated string. For example, if a teammate's
Vite frontend runs at `192.168.1.42:5173`:

```dotenv
CORS_ORIGINS=["http://localhost:5173","http://localhost:3000","http://192.168.1.42:5173"]
```

This setting matters only for browser clients hosted on a different origin. Postman, curl,
and server-to-server clients do not use CORS. Include every peer frontend origin (including
its port) that should be allowed.

Start the shared server without reload mode:

```powershell
uvicorn src.main:app --host 0.0.0.0 --port 8000
```

For local development, `--reload` is fine, but it restarts the shared server whenever files
change:

```powershell
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

Find the host's usable LAN address:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notmatch '^(127|169\.254)\.' } |
  Select-Object IPAddress, InterfaceAlias
```

If a peer cannot connect, add a narrowly scoped Windows Firewall rule from an elevated
PowerShell window. Use the `Private` profile only; do not open this development API on
public networks.

```powershell
New-NetFirewallRule -DisplayName "VibeProof FastAPI (LAN)" -Direction Inbound `
  -Action Allow -Protocol TCP -LocalPort 8000 -Profile Private
```

## Peer setup and smoke test

Share the API base URL in this form:

```text
http://<HOST_IP>:8000/api
```

For a browser frontend, put that value in its configuration as `API_BASE_URL` (without a
trailing slash) and make sure its own origin appears in the host's `CORS_ORIGINS` list.

From a peer machine, first open `http://<HOST_IP>:8000/docs`. Then verify the API directly
with PowerShell's native curl executable:

```powershell
curl.exe http://<HOST_IP>:8000/api/scenarios

curl.exe -i -X POST http://<HOST_IP>:8000/api/sessions `
  -H "Content-Type: application/json" `
  -d '{"display_name":"Peer smoke test","scenario_id":"homepage_latency"}'
```

Expected results are `200 OK` for `/api/scenarios` and `201 Created` for the session. Copy
the returned `session_id` when trying the remaining endpoints in Swagger or a REST client.

## Endpoint directory

All endpoints below use the API base URL (`http://<HOST_IP>:8000/api`). JSON requests should
send `Content-Type: application/json`.

| Method | Path | Purpose | Success |
| --- | --- | --- | --- |
| `GET` | `/scenarios` | List candidate-safe scenarios. | `200` |
| `POST` | `/sessions` | Create an active assessment session and seeded workspace. | `201` |
| `GET` | `/sessions/{session_id}` | Read a session snapshot, including files and chat history. | `200` |
| `POST` | `/sessions/{session_id}/events` | Append a validated frontend-observed event. | `201` |
| `POST` | `/sessions/{session_id}/messages` | Send a candidate message; returns an SSE stream. | `200` stream |
| `GET` | `/sessions/{session_id}/files` | List the session's virtual workspace files. | `200` |
| `GET` | `/sessions/{session_id}/files/{file_path}` | Read one virtual workspace file. | `200` |
| `POST` | `/sessions/{session_id}/tests/{test_id}` | Run a scripted validation test for a remediation. | `200` |
| `POST` | `/sessions/{session_id}/submit` | Submit the final diagnosis and run evaluation. | `200` |
| `GET` | `/sessions/{session_id}/report` | Get the Proof Replay after submission. | `200` |

### Most useful request shapes

Create a session (both fields are optional; the defaults are `Anonymous` and
`homepage_latency`):

```json
{"display_name":"Ada","scenario_id":"homepage_latency"}
```

Record an observed action. Only these frontend event types are accepted:

| Event type | Required payload fields |
| --- | --- |
| `evidence_viewed` | `artifact_id` |
| `hypothesis_recorded` | `version`, `hypothesis_id`, `confidence` |
| `hypothesis_revised` | `previous_version`, `version`, `hypothesis_id`, `confidence`, non-empty `trigger_evidence_ids` |
| `search_performed` | `query` (`scope` and `result_count` are optional) |
| `ai_suggestion_dispositioned` | `response_id`, `option_id` |
| `decision_recorded` | `action`, `rationale` (`risk` is optional) |

For example:

```json
{
  "event_type": "evidence_viewed",
  "payload": {"artifact_id": "metrics_overview"}
}
```

`POST /messages` returns `text/event-stream`, with `token`, `tool_use`, `file_updated`,
`done`, or `error` events. Use `fetch` and read the response stream in browser clients; the
browser `EventSource` API cannot make this POST request.

The complete final-submission schema, SSE event format, response examples, frozen scenario
IDs, and evaluation-report shape are in [00-api-contract.md](00-api-contract.md). The live
`/docs` page is authoritative for the Pydantic-generated schema of the running version.

## Errors and troubleshooting

Every non-success response uses one envelope:

```json
{"error":{"code":"machine_code","message":"Human-readable explanation","details":[]}}
```

- `404` means the session, test, or workspace file does not exist.
- `409` means the session is no longer active, was submitted twice, or the report was requested before submission.
- `422` means the JSON shape, event type, state, or scenario IDs are invalid.
- `503` from `/report` means grading is awaiting manual review.
- A browser-only CORS error means the peer frontend's full origin is missing from `CORS_ORIGINS`; restart the backend after editing `.env`.
- A connection timeout or refusal usually means the server was started without `--host 0.0.0.0`, the wrong LAN IP was shared, or the Private-network firewall rule is missing.

For a stable remote deployment, get backend-owner approval before publishing a URL. Configure
the exact deployed frontend origins in `CORS_ORIGINS` and add the missing security controls
before making the unauthenticated API reachable outside the trusted network.
