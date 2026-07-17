$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $repositoryRoot 'backend'

# ADR 0001: run the interactive session against the TRUE on-disk sandbox (real files + real
# `vitest run`), overriding decision D006 for this local tool only. Set WORKSPACE_BACKEND=db
# before launching to fall back to the DB-rows workspace.
if (-not $env:WORKSPACE_BACKEND) { $env:WORKSPACE_BACKEND = 'fs' }

$virtualEnvironmentPython = Join-Path $backendRoot '.venv\Scripts\python.exe'
$python = if (Test-Path -LiteralPath $virtualEnvironmentPython) { $virtualEnvironmentPython } else { 'python' }

Push-Location $backendRoot
try {
    & $python 'scripts\run_interactive_candidate_session.py'
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
