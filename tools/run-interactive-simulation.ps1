$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $repositoryRoot 'backend'
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
