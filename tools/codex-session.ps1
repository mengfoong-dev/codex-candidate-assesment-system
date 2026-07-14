param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('start', 'stop', 'status')]
    [string]$Action,

    [string]$Goal,
    [string]$Outcome,
    [string]$Agent = 'Codex',
    [Alias('CodexSpend')]
    [string]$UsageSpend = 'MANUAL_ENTRY_REQUIRED',
    [Alias('CodexUnits')]
    [string]$UsageUnits = 'MANUAL_ENTRY_REQUIRED'
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $repoRoot 'docs\hackathon\codex-usage'
$sessionFile = Join-Path $logDirectory 'active-session.json'
$csvFile = Join-Path $logDirectory 'sessions.csv'

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Get-ActiveSession {
    if (-not (Test-Path -LiteralPath $sessionFile)) {
        return $null
    }

    return Get-Content -Raw -LiteralPath $sessionFile | ConvertFrom-Json
}

if ($Action -eq 'start') {
    if (Get-ActiveSession) {
        throw "A Codex session is already active. Run the stop action before starting another one."
    }

    if ([string]::IsNullOrWhiteSpace($Goal)) {
        throw 'The start action requires -Goal.'
    }

    if ([string]::IsNullOrWhiteSpace($Agent)) {
        throw 'The start action requires a non-empty -Agent.'
    }

    $now = [DateTimeOffset]::Now
    $session = [ordered]@{
        session_id = 'S-' + $now.ToString('yyyyMMdd-HHmmss')
        start_time = $now.ToString('o')
        agent = $Agent
        goal = $Goal
    }

    $session | ConvertTo-Json | Set-Content -LiteralPath $sessionFile -Encoding UTF8
    Write-Output "Started $($session.session_id) at $($session.start_time)."
    Write-Output "Goal: $Goal"
    exit 0
}

if ($Action -eq 'status') {
    $active = Get-ActiveSession
    if (-not $active) {
        Write-Output 'No active agent session.'
        exit 0
    }

    $elapsed = ([DateTimeOffset]::Now - [DateTimeOffset]::Parse($active.start_time)).TotalMinutes
    Write-Output "Active session: $($active.session_id)"
    Write-Output "Started: $($active.start_time)"
    Write-Output ("Elapsed minutes: {0:N1}" -f $elapsed)
    Write-Output "Agent: $($active.agent)"
    Write-Output "Goal: $($active.goal)"
    exit 0
}

$activeSession = Get-ActiveSession
if (-not $activeSession) {
    throw 'No active agent session. Start one first.'
}

$end = [DateTimeOffset]::Now
$start = [DateTimeOffset]::Parse($activeSession.start_time)
$duration = [math]::Round(($end - $start).TotalMinutes, 1)

$row = [pscustomobject][ordered]@{
    agent = if ([string]::IsNullOrWhiteSpace($activeSession.agent)) { 'Codex' } else { $activeSession.agent }
    session_id = $activeSession.session_id
    start_time = $activeSession.start_time
    end_time = $end.ToString('o')
    duration_minutes = $duration
    usage_spend = $UsageSpend
    usage_units = $UsageUnits
    goal = $activeSession.goal
    outcome = if ([string]::IsNullOrWhiteSpace($Outcome)) { 'OUTCOME_ENTRY_REQUIRED' } else { $Outcome }
    notes = 'Copy account-level agent spend/usage into this row if available.'
}

if (-not (Test-Path -LiteralPath $csvFile)) {
    $row | Export-Csv -LiteralPath $csvFile -NoTypeInformation -Encoding UTF8
} else {
    $existingRows = @(Import-Csv -LiteralPath $csvFile)
    $normalizedRows = foreach ($existingRow in $existingRows) {
        [pscustomobject][ordered]@{
            agent = if ($existingRow.PSObject.Properties.Name -contains 'agent' -and -not [string]::IsNullOrWhiteSpace($existingRow.agent)) { $existingRow.agent } else { 'Codex' }
            session_id = $existingRow.session_id
            start_time = $existingRow.start_time
            end_time = $existingRow.end_time
            duration_minutes = $existingRow.duration_minutes
            usage_spend = if ($existingRow.PSObject.Properties.Name -contains 'usage_spend') { $existingRow.usage_spend } else { $existingRow.codex_spend }
            usage_units = if ($existingRow.PSObject.Properties.Name -contains 'usage_units') { $existingRow.usage_units } else { $existingRow.codex_units }
            goal = $existingRow.goal
            outcome = $existingRow.outcome
            notes = if ([string]::IsNullOrWhiteSpace($existingRow.notes)) { 'Copy account-level agent spend/usage into this row if available.' } else { $existingRow.notes }
        }
    }

    @($normalizedRows) + $row | Export-Csv -LiteralPath $csvFile -NoTypeInformation -Encoding UTF8
}

Remove-Item -LiteralPath $sessionFile -Force
Write-Output "Stopped $($activeSession.session_id)."
Write-Output "Duration minutes: $duration"
Write-Output "Logged to: $csvFile"
