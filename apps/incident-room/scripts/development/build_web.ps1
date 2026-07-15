$ErrorActionPreference = 'Stop'

$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$distRoot = Join-Path $project 'dist'
$webOutput = Join-Path $distRoot 'web'
$railwayStage = Join-Path $distRoot 'railway-web'
$deploymentSource = Join-Path $project 'deploy\railway-web'
$godot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
$webTemplate = Join-Path $env:APPDATA 'Godot\export_templates\4.7.1.stable\web_nothreads_release.zip'
$verificationScript = Join-Path $PSScriptRoot 'verify_project.ps1'

function Reset-GeneratedDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AllowedRoot
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $expectedPrefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to reset path outside generated root: $fullPath"
    }
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Pinned Godot executable is missing: $godot"
}
if (-not (Test-Path -LiteralPath $webTemplate -PathType Leaf)) {
    throw "Godot 4.7.1 no-thread Web export template is missing: $webTemplate"
}
if (-not (Test-Path -LiteralPath $deploymentSource -PathType Container)) {
    throw "Railway deployment source is missing: $deploymentSource"
}

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $distRoot '.gdignore') -Value '' -NoNewline

& powershell -NoProfile -ExecutionPolicy Bypass -File $verificationScript
if ($LASTEXITCODE -ne 0) {
    throw 'Godot verification failed before Web export'
}

Reset-GeneratedDirectory -Path $webOutput -AllowedRoot $distRoot
Reset-GeneratedDirectory -Path $railwayStage -AllowedRoot $distRoot

$indexPath = Join-Path $webOutput 'index.html'
& $godot --headless --path $project --export-release 'Web' $indexPath
if ($LASTEXITCODE -ne 0) {
    throw 'Godot Web export failed'
}

$requiredExtensions = @('.html', '.js', '.wasm', '.pck')
foreach ($extension in $requiredExtensions) {
    $artifact = Get-ChildItem -LiteralPath $webOutput -File | Where-Object Extension -EQ $extension | Select-Object -First 1
    if ($null -eq $artifact -or $artifact.Length -le 0) {
        throw "Missing or empty Web export artifact: *$extension"
    }
    Write-Output ("WEB_ARTIFACT={0} ({1} bytes)" -f $artifact.Name, $artifact.Length)
}

$siteDirectory = Join-Path $railwayStage 'site'
New-Item -ItemType Directory -Path $siteDirectory -Force | Out-Null
Copy-Item -Path (Join-Path $webOutput '*') -Destination $siteDirectory -Recurse -Force
Copy-Item -LiteralPath (Join-Path $deploymentSource 'Dockerfile') -Destination $railwayStage -Force
Copy-Item -LiteralPath (Join-Path $deploymentSource 'Caddyfile') -Destination $railwayStage -Force
Copy-Item -LiteralPath (Join-Path $deploymentSource 'railway.json') -Destination $railwayStage -Force

Write-Output "WEB_EXPORT=$webOutput"
Write-Output "RAILWAY_STAGE=$railwayStage"
