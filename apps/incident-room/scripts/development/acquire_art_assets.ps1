$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$target = Join-Path $project 'assets\third_party'
$tempRoot = [IO.Path]::GetTempPath()
$temp = Join-Path $tempRoot ('vibeproof-art-' + [guid]::NewGuid().ToString('N'))
$kenneyTarget = Join-Path $target 'kenney-mini-characters'
$kenneyUrl = 'https://kenney.nl/media/pages/assets/mini-characters/bfc7e272b4-1774770718/kenney_mini-characters.zip'
$kenneyHash = '9E1D48E6D7B8479EBBE84DF71EB5BD8E1B3F0DA546DEA641890DCCC8A02D0999'

# Regenerates the Kenney Mini Characters (CC0). The isometric office environment is
# user-provided (Sketchfab, login-gated) and vendored by hand, so it is not scripted here.
New-Item -ItemType Directory -Path $temp, $kenneyTarget -Force | Out-Null
try {
  $zip = Join-Path $temp 'mini.zip'
  $expanded = Join-Path $temp 'mini'
  Invoke-WebRequest -Uri $kenneyUrl -OutFile $zip -UseBasicParsing
  if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $kenneyHash) { throw 'Kenney archive hash mismatch.' }
  Expand-Archive -LiteralPath $zip -DestinationPath $expanded
  $glbDir = Join-Path $expanded 'Models\GLB format'
  # Vendor all 12 character variants (player, senior NPC, and the seated coworkers).
  Get-ChildItem -LiteralPath $glbDir -Filter 'character-*.glb' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $kenneyTarget -Force
  }
  # The GLBs reference their shared atlas at the relative path 'Textures/colormap.png'.
  $colormap = Get-ChildItem -LiteralPath $glbDir -Recurse -Filter 'colormap.png' | Select-Object -First 1
  if ($null -eq $colormap) { throw 'Kenney colormap.png not found in GLB format folder.' }
  $texTarget = Join-Path $kenneyTarget 'Textures'
  New-Item -ItemType Directory -Path $texTarget -Force | Out-Null
  Copy-Item -LiteralPath $colormap.FullName -Destination (Join-Path $texTarget 'colormap.png') -Force
  Copy-Item -LiteralPath (Join-Path $expanded 'License.txt') -Destination (Join-Path $kenneyTarget 'LICENSE.txt') -Force
} finally {
  # Guard: only recursively remove a directory that actually resolves under the system temp root.
  if (Test-Path -LiteralPath $temp) {
    $resolved = (Resolve-Path -LiteralPath $temp).Path
    $resolvedRoot = (Resolve-Path -LiteralPath $tempRoot).Path
    if (-not $resolved.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove temp path outside system temp: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
