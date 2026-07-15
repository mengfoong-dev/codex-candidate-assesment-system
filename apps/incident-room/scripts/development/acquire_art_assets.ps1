$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$target = Join-Path $project 'assets\third_party'
$tempRoot = [IO.Path]::GetTempPath()
$temp = Join-Path $tempRoot ('vibeproof-art-' + [guid]::NewGuid().ToString('N'))
$kayTarget = Join-Path $target 'kaykit-furniture-bits'
$kenneyTarget = Join-Path $target 'kenney-mini-characters'
$kayRevision = '96d5930a8dbdb363409bbc2d3341718b00e17c9c'
$kenneyUrl = 'https://kenney.nl/media/pages/assets/mini-characters/bfc7e272b4-1774770718/kenney_mini-characters.zip'
$kenneyHash = '9E1D48E6D7B8479EBBE84DF71EB5BD8E1B3F0DA546DEA641890DCCC8A02D0999'
$models = @(
  'armchair_pillows','book_set','cabinet_medium_decorated','cactus_medium_A',
  'chair_C','couch_pillows','lamp_standing','rug_rectangle_stripes_A',
  'shelf_B_large_decorated','table_medium_long','table_small'
)

New-Item -ItemType Directory -Path $temp,$kayTarget,$kenneyTarget -Force | Out-Null
try {
  $kaySource = Join-Path $temp 'kaykit'
  git clone --quiet https://github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0.git $kaySource
  git -C $kaySource checkout --quiet $kayRevision
  if ((git -C $kaySource rev-parse HEAD).Trim() -ne $kayRevision) { throw 'KayKit revision mismatch.' }
  $gltf = Join-Path $kaySource 'addons\kaykit_furniture_bits\Assets\gltf'
  foreach ($model in $models) {
    Copy-Item -LiteralPath (Join-Path $gltf "$model.gltf") -Destination $kayTarget -Force
    Copy-Item -LiteralPath (Join-Path $gltf "$model.bin") -Destination $kayTarget -Force
  }
  Copy-Item -LiteralPath (Join-Path $gltf 'furniturebits_texture.png') -Destination $kayTarget -Force
  Copy-Item -LiteralPath (Join-Path $kaySource 'LICENSE.txt') -Destination $kayTarget -Force

  $zip = Join-Path $temp 'mini.zip'
  $expanded = Join-Path $temp 'mini'
  Invoke-WebRequest -Uri $kenneyUrl -OutFile $zip -UseBasicParsing
  if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $kenneyHash) { throw 'Kenney archive hash mismatch.' }
  Expand-Archive -LiteralPath $zip -DestinationPath $expanded
  $glbDir = Join-Path $expanded 'Models\GLB format'
  Copy-Item -LiteralPath (Join-Path $glbDir 'character-female-a.glb') -Destination $kenneyTarget -Force
  # The GLB references its shared atlas at the relative path 'Textures/colormap.png'; preserve that layout.
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
