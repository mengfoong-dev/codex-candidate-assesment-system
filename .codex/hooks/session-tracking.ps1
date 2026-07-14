$inputText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputText)) {
    exit 0
}

try {
    $event = $inputText | ConvertFrom-Json
} catch {
    exit 0
}

$repoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    exit 0
}

$logger = Join-Path $repoRoot 'tools\codex-session.ps1'
$sessionFile = Join-Path $repoRoot 'docs\hackathon\codex-usage\active-session.json'
$staleAfterMinutes = 120

if (-not (Test-Path -LiteralPath $logger)) {
    exit 0
}

if ($event.hook_event_name -eq 'UserPromptSubmit') {
    if (Test-Path -LiteralPath $sessionFile) {
        try {
            $active = Get-Content -Raw -LiteralPath $sessionFile | ConvertFrom-Json
            $ageMinutes = ([DateTimeOffset]::Now - [DateTimeOffset]::Parse($active.start_time)).TotalMinutes
        } catch {
            $ageMinutes = 0
        }

        if ($ageMinutes -lt $staleAfterMinutes) {
            exit 0
        }

        $staleOutcome = 'Automatically closed stale Codex session after {0:N0} minutes; elapsed time may include idle time.' -f $ageMinutes
        & powershell -NoProfile -ExecutionPolicy Bypass -File $logger stop -Outcome $staleOutcome 1>$null 2>$null

        if (Test-Path -LiteralPath $sessionFile) {
            exit 0
        }
    }

    $goal = [string]$event.prompt
    if ([string]::IsNullOrWhiteSpace($goal)) {
        $goal = 'Codex repository task'
    }

    if ($goal.Length -gt 500) {
        $goal = $goal.Substring(0, 497) + '...'
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $logger start -Agent 'Codex' -Goal $goal 1>$null 2>$null
    exit 0
}

if ($event.hook_event_name -eq 'Stop') {
    if (-not (Test-Path -LiteralPath $sessionFile)) {
        exit 0
    }

    if ($event.stop_hook_active -eq $true) {
        exit 0
    }

    $response = [ordered]@{
        decision = 'block'
        reason = 'Before finishing, run the project session logger: powershell -ExecutionPolicy Bypass -File .\tools\codex-session.ps1 stop -Outcome "<summary of completed work and verification>". Then finish your response.'
    }
    $response | ConvertTo-Json -Compress
    exit 0
}

exit 0
