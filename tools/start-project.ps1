[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$BackendPort = 8000
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $repositoryRoot "backend"
$godotProjectPath = Join-Path $repositoryRoot "apps\incident-room"
$godotPath = Join-Path $env:LOCALAPPDATA "VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
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

$uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uv) {
    throw "uv was not found on PATH. Install uv, then run this command again."
}

if (-not (Test-Path -LiteralPath $godotPath)) {
    throw "Godot 4.7.1 was not found at $godotPath. Install the pinned Standard build from README.md."
}

if (Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object LocalPort -eq $BackendPort) {
    throw "Port $BackendPort is already in use. Stop the existing service or run with -BackendPort <port>."
}

$backendProcess = Start-Process `
    -FilePath $uv.Source `
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
