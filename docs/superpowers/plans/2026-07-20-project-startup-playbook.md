# Project Startup Playbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide one PowerShell command that starts the Godot Incident Room and its local FastAPI backend, then document the verified whole-project state.

**Architecture:** `tools/start-project.ps1` will stay a thin process launcher. It validates the pinned Godot executable and `uv`, reserves the existing local-only backend port, starts Uvicorn from `backend/`, waits for the real `/api/scenarios` endpoint, and only then starts the interactive Godot application. Documentation records the command, prerequisites, observed verification, and known scope.

**Tech Stack:** PowerShell 7, Godot 4.7.1 Standard, Python 3.11+, uv, FastAPI/Uvicorn.

## Global Constraints

- Reuse the existing Godot 4.7.1 path and `uv run uvicorn src.main:app` command; add no dependencies.
- Bind Uvicorn to `127.0.0.1` only; LAN sharing remains the manual command in `docs/backend/API_ACCESS.md`.
- Do not touch existing user changes under `apps/incident-room/` or `docs/pitch/`.
- Treat `GET /api/scenarios` returning HTTP 200 as backend readiness because the project has no health route.
- The Godot process must remain visible; the backend helper process runs hidden and writes its startup output to `%TEMP%`.

---

### Task 1: Implement the one-command launcher

**Files:**
- Create: `tools/start-project.ps1`
- Test: Manual end-to-end command from repository root.

**Interfaces:**
- Consumes: `uv` on `PATH`, `backend/`, `apps/incident-room/`, and `%LOCALAPPDATA%\\VibeProof\\Godot\\4.7.1\\Godot_v4.7.1-stable_win64.exe`.
- Produces: a running Uvicorn process listening on `127.0.0.1:8000`, an HTTP 200 response from `/api/scenarios`, and one visible Godot process.

- [ ] **Step 1: Write the failing operational check**

Run the command below before the script exists. Expected: PowerShell reports that `tools/start-project.ps1` does not exist.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-project.ps1
```

- [ ] **Step 2: Create the minimal launcher**

Create `tools/start-project.ps1` with this complete content:

```powershell
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$BackendPort = 8000
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $repositoryRoot "backend"
$godotProjectPath = Join-Path $repositoryRoot "apps\\incident-room"
$godotPath = Join-Path $env:LOCALAPPDATA "VibeProof\\Godot\\4.7.1\\Godot_v4.7.1-stable_win64.exe"
$backendUrl = "http://127.0.0.1:$BackendPort/api/scenarios"
$backendOutputLog = Join-Path $env:TEMP "vibeproof-backend-$BackendPort.out.log"
$backendErrorLog = Join-Path $env:TEMP "vibeproof-backend-$BackendPort.err.log"

function Stop-ProcessTree {
    param([Parameter(Mandatory)] [int]$ProcessId)

    $children = Get-CimInstance -ClassName Win32_Process `
        -Filter "ParentProcessId = $ProcessId" `
        -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        Stop-ProcessTree -ProcessId $child.ProcessId
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv was not found on PATH. Install uv, then run this command again."
}

if (-not (Test-Path -LiteralPath $godotPath)) {
    throw "Godot 4.7.1 was not found at $godotPath. Install the pinned Standard build from README.md."
}

if (Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object LocalPort -eq $BackendPort) {
    throw "Port $BackendPort is already in use. Stop the existing service or run with -BackendPort <port>."
}

$backendProcess = Start-Process `
    -FilePath (Get-Command uv).Source `
    -ArgumentList @("run", "uvicorn", "src.main:app", "--host", "127.0.0.1", "--port", $BackendPort) `
    -WorkingDirectory $backendPath `
    -RedirectStandardOutput $backendOutputLog `
    -RedirectStandardError $backendErrorLog `
    -WindowStyle Hidden `
    -PassThru

$ready = $false
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
    try {
        if ((Invoke-WebRequest -Uri $backendUrl -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 500
    }
}

if (-not $ready) {
    Stop-ProcessTree -ProcessId $backendProcess.Id
    throw "Backend did not become ready within 30 seconds. Read $backendOutputLog and $backendErrorLog."
}

try {
    $godotProcess = Start-Process `
        -FilePath $godotPath `
        -ArgumentList "--path `"$godotProjectPath`"" `
        -WorkingDirectory $repositoryRoot `
        -PassThru
} catch {
    Stop-ProcessTree -ProcessId $backendProcess.Id
    throw
}

Start-Sleep -Seconds 1
$godotProcess.Refresh()
if ($godotProcess.HasExited) {
    Stop-ProcessTree -ProcessId $backendProcess.Id
    throw "Godot exited during startup. The backend process was stopped; inspect the Godot output."
}

Write-Host "Backend ready: $backendUrl (PID $($backendProcess.Id))"
Write-Host "Godot launched: $godotProjectPath (PID $($godotProcess.Id))"
Write-Host "Backend logs: $backendOutputLog and $backendErrorLog"
```

- [ ] **Step 3: Run the end-to-end check**

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-project.ps1
```

Expected: two process IDs are printed, `http://127.0.0.1:8000/api/scenarios` returns HTTP 200, and the Godot window remains open after the command exits.

- [ ] **Step 4: Confirm the real backend response and Godot process**

```powershell
(Invoke-WebRequest http://127.0.0.1:8000/api/scenarios -UseBasicParsing).StatusCode
Get-Process Godot* | Select-Object Id, ProcessName, StartTime
```

Expected: status `200` and one active Godot process created during the startup run.

### Task 2: Document normal startup and the project-wide state

**Files:**
- Create: `docs/STARTUP-PLAYBOOK.md`
- Create: `docs/FINAL-STATE.md`
- Modify: `README.md`
- Modify: `docs/README.md`
- Test: Read the documentation commands against `tools/start-project.ps1` and the observed run output.

**Interfaces:**
- Consumes: the launcher contract from Task 1 and its fresh end-to-end evidence.
- Produces: a discoverable one-command setup guide and a project-level operational handoff in the existing backend final-state format.

- [ ] **Step 1: Add the startup playbook**

Create `docs/STARTUP-PLAYBOOK.md` with the prerequisite locations, the exact one-command invocation, expected output, local URLs, the temporary backend log path, and narrow fixes for missing Godot, missing `uv`, and occupied port 8000. State that senior-proxy, code-runner, Remotion, and Web export are optional and not started.

- [ ] **Step 2: Surface the one-command flow**

Insert a short `### Start both services` subsection immediately above the root README's existing `### 1. Run the Godot Incident Room` section:

```markdown
### Start both services

From the repository root, launch the FastAPI backend, wait for its scenario endpoint,
then open the Godot candidate app:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-project.ps1
```

See [the startup playbook](docs/STARTUP-PLAYBOOK.md) for prerequisites, verification, and troubleshooting.
```

Add `STARTUP-PLAYBOOK.md` and `FINAL-STATE.md` links to the `docs/README.md` operational-records section.

- [ ] **Step 3: Create the final-state handoff after the fresh run**

Create `docs/FINAL-STATE.md` with the same sections used by `docs/backend/FINAL-STATE.md`: `Updated`, `Status`, `Delivered project state`, `Live architecture`, `Candidate and frontend flow`, `Local commands`, `Verification evidence`, and `Remaining operational acceptance`. Include only today’s observed launcher output and the fact that the Godot process was launched. State that a human visual journey remains outside the automated startup check.

- [ ] **Step 4: Run documentation and diff checks**

```powershell
git diff --check
git diff -- tools/start-project.ps1 README.md docs/README.md docs/STARTUP-PLAYBOOK.md docs/FINAL-STATE.md
```

Expected: no whitespace errors; the diff contains only the launcher and its documentation plus pre-existing user changes outside this task.

## Plan self-review

- **Spec coverage:** Task 1 creates and runs the frontend/backend startup script. Task 2 creates the project-level final-state file using the existing backend handoff structure and makes the playbook discoverable.
- **Placeholder scan:** No implementation or verification step uses placeholders; task-specific values, paths, commands, and expected results are explicit.
- **Type consistency:** The script consistently accepts `BackendPort` as an integer, runs Uvicorn against `127.0.0.1`, and probes the matching `/api/scenarios` URL.

## Execution Handoff

Inline execution is selected because the task explicitly requires the startup script to be run in this session.
