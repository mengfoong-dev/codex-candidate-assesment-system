[CmdletBinding()]
param(
    [string]$ProjectPath = '',
    [string]$GodotPath = (Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = Join-Path $PSScriptRoot '..\..' }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf) -or (Get-Item -LiteralPath $GodotPath).Length -le 0) { throw "Godot executable not found: $GodotPath" }
$project = (Resolve-Path -LiteralPath $ProjectPath).Path

& $GodotPath --headless --path $project --import
if ($LASTEXITCODE -ne 0) { throw 'Godot editor import failed' }

$missingUids = @()
foreach ($relativeRoot in @('scripts', 'tests')) {
    $scanRoot = Join-Path $project $relativeRoot
    foreach ($scriptFile in Get-ChildItem -LiteralPath $scanRoot -Filter '*.gd' -File -Recurse) {
        $uidPath = $scriptFile.FullName + '.uid'
        if (-not (Test-Path -LiteralPath $uidPath -PathType Leaf) -or (Get-Item -LiteralPath $uidPath).Length -le 0) {
            $missingUids += $uidPath
        }
    }
}
if ($missingUids.Count -gt 0) { throw "Missing or empty Godot script UID sidecars: $($missingUids -join ', ')" }

& $GodotPath --headless --path $project --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { throw 'Godot headless tests failed' }
