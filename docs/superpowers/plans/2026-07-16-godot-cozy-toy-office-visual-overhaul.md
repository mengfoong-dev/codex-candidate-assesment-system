# Godot Cozy Toy Office Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the primitive Incident Room presentation with a cohesive CC0 Cozy Toy Office, animated employee, polished stations, and matching UI without changing candidate evidence behavior.

**Architecture:** Keep domain, persistence, station IDs, collision, and coordinator contracts unchanged. Acquire pinned third-party files through a deterministic PowerShell script, wrap imported models in local presentation scenes, and compose those wrappers into room, player, station, and UI layers that remain independently testable.

**Tech Stack:** Godot 4.7.1 Compatibility renderer, GDScript, GLTF/GLB, PowerShell 5.1, KayKit Furniture Bits 1.0, Kenney Mini Characters 1.0, existing headless Godot test runner, Windows and single-threaded Web exports.

## Global Constraints

- Work directly on the authorized `main` branch and never force-push.
- Preserve all existing candidate state, event payloads, scenario IDs, station IDs, persistence behavior, and unscored summaries.
- Keep the fixed elevated orthographic camera and existing movement/quick-access controls.
- Import only files selected in the manifest; do not commit complete unrelated source archives.
- Use only verified CC0 assets from the canonical KayKit GitHub repository and Kenney download.
- Keep textures at 1024 pixels or below.
- Use one shadow-casting directional light; station lights do not cast shadows.
- Keep additional compressed Web download below 20 MB.
- Commit generated `*.gd.uid` sidecars.
- Run the full Godot verification command before every task commit that changes runtime files.

---

### Task 1: Reproducible CC0 asset acquisition and provenance

**Files:**
- Create: `apps/incident-room/tests/test_art_asset_contract.gd`
- Create: `apps/incident-room/assets/third_party/asset_manifest.json`
- Create: `apps/incident-room/scripts/development/acquire_art_assets.ps1`
- Create through script: `apps/incident-room/assets/third_party/kaykit-furniture-bits/`
- Create through script: `apps/incident-room/assets/third_party/kenney-mini-characters/`
- Modify: `apps/incident-room/THIRD_PARTY_NOTICES.md`

**Interfaces:**
- Consumes: canonical KayKit Git commit `96d5930a8dbdb363409bbc2d3341718b00e17c9c` and Kenney ZIP SHA-256 `9E1D48E6D7B8479EBBE84DF71EB5BD8E1B3F0DA546DEA641890DCCC8A02D0999`.
- Produces: `asset_manifest.json`, selected GLTF/GLB files, local CC0 license copies, and deterministic asset paths used by every later task.

- [ ] **Step 1: Add the failing asset contract suite**

Create `test_art_asset_contract.gd` with:

```gdscript
extends RefCounted

const MANIFEST_PATH := "res://assets/third_party/asset_manifest.json"
const REQUIRED_FILES := [
    "res://assets/third_party/kaykit-furniture-bits/LICENSE.txt",
    "res://assets/third_party/kaykit-furniture-bits/furniturebits_texture.png",
    "res://assets/third_party/kaykit-furniture-bits/table_medium_long.gltf",
    "res://assets/third_party/kaykit-furniture-bits/table_medium_long.bin",
    "res://assets/third_party/kaykit-furniture-bits/chair_C.gltf",
    "res://assets/third_party/kaykit-furniture-bits/chair_C.bin",
    "res://assets/third_party/kaykit-furniture-bits/shelf_B_large_decorated.gltf",
    "res://assets/third_party/kaykit-furniture-bits/shelf_B_large_decorated.bin",
    "res://assets/third_party/kenney-mini-characters/LICENSE.txt",
    "res://assets/third_party/kenney-mini-characters/character-female-a.glb",
]

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    t.assert_true(FileAccess.file_exists(MANIFEST_PATH), "art asset manifest exists")
    if not FileAccess.file_exists(MANIFEST_PATH):
        return t.failures
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    t.assert_true(parsed is Dictionary, "art asset manifest is a JSON object")
    if parsed is Dictionary:
        t.assert_equal(parsed.get("schema_version"), 1, "manifest schema version")
        t.assert_equal(parsed.get("packs", []).size(), 2, "two CC0 packs recorded")
    for path: String in REQUIRED_FILES:
        t.assert_true(FileAccess.file_exists(path), "required art asset exists: %s" % path)
    var notices := FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md")
    t.assert_true(notices.contains("KayKit: Furniture Bits 1.0"), "KayKit notice recorded")
    t.assert_true(notices.contains("Kenney Mini Characters 1.0"), "Kenney notice recorded")
    return t.failures
```

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
```

Expected: `test_art_asset_contract.gd` fails because the manifest and selected assets do not exist.

- [ ] **Step 3: Add the pinned manifest**

Create `asset_manifest.json` with this exact structure:

```json
{
  "schema_version": 1,
  "packs": [
    {
      "id": "kaykit-furniture-bits-1.0",
      "creator": "Kay Lousberg",
      "source": "https://github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0",
      "revision": "96d5930a8dbdb363409bbc2d3341718b00e17c9c",
      "license": "CC0-1.0",
      "selected_models": [
        "armchair_pillows", "book_set", "cabinet_medium_decorated",
        "cactus_medium_A", "chair_C", "couch_pillows", "lamp_standing",
        "rug_rectangle_stripes_A", "shelf_B_large_decorated",
        "table_medium_long", "table_small"
      ]
    },
    {
      "id": "kenney-mini-characters-1.0",
      "creator": "Kenney",
      "source": "https://kenney.nl/assets/mini-characters",
      "download": "https://kenney.nl/media/pages/assets/mini-characters/bfc7e272b4-1774770718/kenney_mini-characters.zip",
      "sha256": "9E1D48E6D7B8479EBBE84DF71EB5BD8E1B3F0DA546DEA641890DCCC8A02D0999",
      "license": "CC0-1.0",
      "selected_models": ["character-female-a.glb"]
    }
  ]
}
```

- [ ] **Step 4: Add deterministic acquisition**

Implement `acquire_art_assets.ps1` so it:

```powershell
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$target = Join-Path $project 'assets\third_party'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('vibeproof-art-' + [guid]::NewGuid().ToString('N'))
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
  Copy-Item -LiteralPath (Join-Path $expanded 'Models\GLB format\character-female-a.glb') -Destination $kenneyTarget -Force
  Copy-Item -LiteralPath (Join-Path $expanded 'License.txt') -Destination (Join-Path $kenneyTarget 'LICENSE.txt') -Force
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
```

The implementation must resolve `$temp` and verify it starts with `[IO.Path]::GetTempPath()` before recursive removal.

- [ ] **Step 5: Add distribution notices and acquire files**

Append concise KayKit and Kenney CC0 sections to `THIRD_PARTY_NOTICES.md`, including creator, version, canonical source, selected-file boundary, and local license path. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/acquire_art_assets.ps1
```

Expected: selected files exist under the two creator-specific directories; no ZIP or `.git` directory enters the repository.

- [ ] **Step 6: Run GREEN and commit**

Run the full verifier. Expected: `TESTS PASSED: 11 suites`.

```powershell
git add apps/incident-room/assets/third_party apps/incident-room/scripts/development/acquire_art_assets.ps1 apps/incident-room/tests/test_art_asset_contract.gd apps/incident-room/THIRD_PARTY_NOTICES.md
git commit -m "assets: add the pinned Cozy Toy Office packs"
```

---

### Task 2: Local prop wrappers and shared 3D palette

**Files:**
- Create: `apps/incident-room/scenes/art/office_prop_library.tscn`
- Create: `apps/incident-room/resources/materials/cream_architecture.tres`
- Create: `apps/incident-room/resources/materials/navy_trim.tres`
- Create: `apps/incident-room/resources/materials/warm_wood.tres`
- Create: `apps/incident-room/resources/materials/station_cyan.tres`
- Create: `apps/incident-room/resources/materials/station_violet.tres`
- Create: `apps/incident-room/resources/materials/station_green.tres`
- Create: `apps/incident-room/resources/materials/station_amber.tres`
- Modify: `apps/incident-room/tests/test_art_asset_contract.gd`

**Interfaces:**
- Consumes: selected KayKit GLTF resources from Task 1.
- Produces: stable wrapper nodes named `Desk`, `Chair`, `Shelf`, `Cabinet`, `Lounge`, `Plant`, `Lamp`, `Books`, and `Rug` for room composition.

- [ ] **Step 1: Extend the contract test for wrappers**

Add assertions that `office_prop_library.tscn` loads, instantiates as `Node3D`, contains all nine stable wrapper names, and has no `CollisionObject3D` descendants.

- [ ] **Step 2: Run RED**

Expected: failure because `office_prop_library.tscn` does not exist.

- [ ] **Step 3: Create the palette resource**

Create seven independently loadable `StandardMaterial3D` resources for cream architecture, navy trim, warm wood, cyan, violet, green, and amber. Use matte roughness values from `0.68` to `0.9`; enable emission only on cyan, violet, green, and amber. Independent files let wrapper and station scenes reference a material directly without a custom palette loader.

- [ ] **Step 4: Create the wrapper library**

Create `office_prop_library.tscn` with external GLTF resources and these mappings:

```text
Desk    -> table_medium_long.gltf
Chair   -> chair_C.gltf
Shelf   -> shelf_B_large_decorated.gltf
Cabinet -> cabinet_medium_decorated.gltf
Lounge  -> couch_pillows.gltf + armchair_pillows.gltf
Plant   -> cactus_medium_A.gltf
Lamp    -> lamp_standing.gltf
Books   -> book_set.gltf
Rug     -> rug_rectangle_stripes_A.gltf
```

Each mapping is a `Node3D` parent around one imported instance so transforms can be normalized without editing the third-party model.

- [ ] **Step 5: Run GREEN, import, and commit**

Run the verifier, confirm `TESTS PASSED: 11 suites`, and commit:

```powershell
git add apps/incident-room/scenes/art apps/incident-room/resources/materials apps/incident-room/tests/test_art_asset_contract.gd apps/incident-room/**/*.uid
git commit -m "feat: add reusable Cozy Toy Office props"
```

---

### Task 3: Animated employee presentation

**Files:**
- Create: `apps/incident-room/tests/test_player_visual_contract.gd`
- Create: `apps/incident-room/scripts/presentation/player_visual.gd`
- Create: `apps/incident-room/scenes/player/player_visual.tscn`
- Modify: `apps/incident-room/scenes/player/player.tscn`
- Modify: `apps/incident-room/scripts/presentation/player_controller.gd`

**Interfaces:**
- Consumes: `character-female-a.glb`, whose animation names include `idle` and `walk`.
- Produces: `PlayerVisual.set_moving(moving: bool) -> void`; the controller calls it after movement without depending on imported node paths.

- [ ] **Step 1: Write the failing visual contract**

The new suite must instantiate `player.tscn` and assert:

```gdscript
var visual := player.get_node_or_null("Visual")
t.assert_true(visual != null, "player has a visual adapter")
t.assert_true(visual.has_method("set_moving"), "visual adapter exposes set_moving")
t.assert_true(visual.get_node_or_null("Character") != null, "visual contains the imported employee")
t.assert_true(player.get_node_or_null("CollisionShape3D") is CollisionShape3D, "collision remains independent")
t.assert_true(player.get_node_or_null("Body") == null, "prototype capsule body is removed")
```

- [ ] **Step 2: Run RED**

Expected: failure because `Visual` does not exist and `Body` still exists.

- [ ] **Step 3: Implement the adapter**

Create `player_visual.gd`:

```gdscript
class_name PlayerVisual
extends Node3D

@export var idle_animation := "idle"
@export var walk_animation := "walk"

var _animation_player: AnimationPlayer
var _current := ""

func _ready() -> void:
    var candidates := find_children("*", "AnimationPlayer", true, false)
    if not candidates.is_empty():
        _animation_player = candidates[0] as AnimationPlayer
    set_moving(false)

func set_moving(moving: bool) -> void:
    var requested := walk_animation if moving else idle_animation
    if requested == _current or _animation_player == null:
        return
    if not _animation_player.has_animation(requested):
        push_warning("Player visual is missing animation: %s" % requested)
        return
    _animation_player.play(requested, 0.15)
    _current = requested
```

- [ ] **Step 4: Replace only the visual child**

Create `player_visual.tscn` with the Kenney GLB scaled to the current 1.7-meter collision height, add a soft `Decal`-free flattened `CylinderMesh` blob shadow, and attach the adapter. In `player.tscn`, remove `Body` and `Direction`, then instance the wrapper as `Visual`; retain the collision shape unchanged.

- [ ] **Step 5: Drive animation from velocity**

In `player_controller.gd`, cache `$Visual` and call:

```gdscript
player_visual.set_moving(input_enabled and Vector2(velocity.x, velocity.z).length_squared() > 0.04)
```

Call `set_moving(false)` in the input-disabled branch before returning.

- [ ] **Step 6: Run GREEN and commit**

Expected: `TESTS PASSED: 12 suites`.

```powershell
git add apps/incident-room/scenes/player apps/incident-room/scripts/presentation/player_controller.gd apps/incident-room/scripts/presentation/player_visual.gd apps/incident-room/tests/test_player_visual_contract.gd
git commit -m "feat: animate the Incident Room employee"
```

---

### Task 4: Cozy office shell and furniture composition

**Files:**
- Create: `apps/incident-room/scenes/room/cozy_office_shell.tscn`
- Create: `apps/incident-room/scenes/room/cozy_office_dressing.tscn`
- Modify: `apps/incident-room/scenes/room/incident_room.tscn`
- Modify: `apps/incident-room/tests/test_room_contracts.gd`

**Interfaces:**
- Consumes: prop wrappers and palette from Task 2.
- Produces: room children `Architecture/CozyOfficeShell` and `Dressing`, while retaining `Architecture/Floor`, wall collisions, one camera, three trigger IDs, and `Player`.

- [ ] **Step 1: Extend room-contract RED assertions**

Assert the shell and dressing exist, the dressing contains at least 18 `Node3D` descendants, `Architecture/Floor` still has collision, the room has one orthographic camera, and all three stable station IDs remain unchanged.

- [ ] **Step 2: Run RED**

Expected: missing `CozyOfficeShell` and `Dressing`.

- [ ] **Step 3: Build the cutaway shell**

Create a 16-by-10-meter shell with a cream floor surface, navy skirting, warm rear and left walls, three rear window panels, a left doorway, and low partitions. Keep the current invisible collision floor and wall boundaries as the authoritative physics layer.

- [ ] **Step 4: Compose the furniture layer**

Place wrapper instances at these room-space anchors, then add small duplicates without blocking the center aisle:

```text
Developer cluster: x 4.8, z -3.4 — Desk, Chair, Lamp, Books, Cabinet
Observability lounge: x -5.4, z -2.9 — Lounge, Rug, Plant
Release cluster: x 4.9, z 3.1 — Desk, Chair, Shelf
Ambient rear dressing: x -1.5..2.0, z -4.3 — Shelf, Cabinet, Plant, Books
Entrance lounge: x -5.4, z 3.1 — Armchair, TableSmall, Lamp, Plant
```

Keep the rectangular corridor from `x=-1.6..1.6`, `z=-3.6..4.4` free of tall furniture.

- [ ] **Step 5: Replace prototype room meshes**

Instance both new scenes in `incident_room.tscn`; retain primitive floor/wall collision but hide or remove the old visible floor, wall, and center-path meshes once the shell covers them. Update the environment background to warm navy, ambient energy to `0.55`, and directional light color to warm cream while keeping only that light shadow-enabled.

- [ ] **Step 6: Run GREEN and commit**

Expected: all 12 suites pass.

```powershell
git add apps/incident-room/scenes/room apps/incident-room/tests/test_room_contracts.gd
git commit -m "feat: rebuild the Incident Room as a cozy office"
```

---

### Task 5: Distinct station landmarks and restrained effects

**Files:**
- Create: `apps/incident-room/scenes/stations/observability_station_visual.tscn`
- Create: `apps/incident-room/scenes/stations/developer_station_visual.tscn`
- Create: `apps/incident-room/scenes/stations/release_station_visual.tscn`
- Create: `apps/incident-room/scripts/presentation/station_visual.gd`
- Modify: `apps/incident-room/scenes/stations/station_trigger.tscn`
- Modify: `apps/incident-room/scripts/presentation/station_trigger.gd`
- Modify: `apps/incident-room/scenes/room/incident_room.tscn`
- Modify: `apps/incident-room/tests/test_room_contracts.gd`

**Interfaces:**
- Consumes: stable station IDs and `accent_color`.
- Produces: each trigger has a `Landmark` scene and `StationVisual.set_active(active: bool) -> void`; proximity changes animate emission without writing candidate events.

- [ ] **Step 1: Add failing landmark assertions**

For every stable station, assert a `Landmark` child exists, no descendant light has `shadow_enabled=true`, and the landmark exposes `set_active`.

- [ ] **Step 2: Run RED**

Expected: current primitive station boxes have no landmark adapter.

- [ ] **Step 3: Build the three landmarks**

- Observability: three cyan emissive screens, wall frame, console shelf, and chart-like mesh bars.
- Developer: imported desk/chair props, two violet screens, keyboard blocks, task lamp, and notes.
- Release: raised standing console, green status screen, status tower, and one amber accent mesh.

Use unshaded screen materials where appropriate; any `OmniLight3D` uses energy at or below `0.55`, range at or below `3.5`, and shadows disabled.

- [ ] **Step 4: Implement proximity animation**

Create `station_visual.gd` with a tween that scales `PromptRing` between `0.92` and `1.04` and adjusts emission energy between idle and active values. Update `station_trigger.gd` to call `set_active(true)` on body entry and `set_active(false)` on exit without changing signal or station-ID behavior.

- [ ] **Step 5: Replace station instances**

Allow `station_trigger.tscn` to keep the `Area3D`, collision, and label contract while each room instance supplies its station-specific landmark. Remove the visible prototype box mesh after all landmarks load.

- [ ] **Step 6: Run GREEN and commit**

```powershell
git add apps/incident-room/scenes/stations apps/incident-room/scenes/room/incident_room.tscn apps/incident-room/scripts/presentation/station_trigger.gd apps/incident-room/scripts/presentation/station_visual.gd apps/incident-room/tests/test_room_contracts.gd
git commit -m "feat: give each investigation station a landmark"
```

---

### Task 6: Shared UI theme, title polish, and interaction prompt

**Files:**
- Create: `apps/incident-room/resources/ui/cozy_office_theme.tres`
- Create: `apps/incident-room/scenes/ui/interaction_prompt.tscn`
- Create: `apps/incident-room/scripts/presentation/interaction_prompt.gd`
- Modify: all six `apps/incident-room/scenes/ui/*.tscn` panel scenes
- Modify: `apps/incident-room/scenes/main/main.tscn`
- Modify: `apps/incident-room/scripts/presentation/main.gd`
- Modify: `apps/incident-room/tests/test_panel_contracts.gd`

**Interfaces:**
- Consumes: current panel node paths, signals, configure methods, and nearest-station updates.
- Produces: a shared `Theme`, `InteractionPrompt.show_station(title: String)`, and `InteractionPrompt.show_default()`.

- [ ] **Step 1: Add failing UI contract assertions**

Assert every panel root has the same non-null `Theme`, all interactive controls retain keyboard focus, and `main.tscn` contains `UI/HUD/InteractionPrompt` exposing both prompt methods.

- [ ] **Step 2: Run RED**

Expected: panels have no shared theme and the prompt scene is absent.

- [ ] **Step 3: Create the shared theme**

Define font sizes, cream/navy colors, focus outlines, rounded `StyleBoxFlat` resources, 12-pixel corner radii, 2-pixel cyan focus borders, 14-pixel button padding, and disabled-state contrast. Assign the theme at each panel root without changing child names used by tests or scripts.

- [ ] **Step 4: Build the prompt component**

Create a bottom-centered rounded card with a keycap-style `E`, station title, and secondary `1 / 2 / 3 quick access` label. Implement:

```gdscript
class_name InteractionPrompt
extends Control

@onready var action_label: Label = $Card/Margin/Layout/Action

func show_default() -> void:
    action_label.text = "Explore stations • 1 / 2 / 3 quick access • H hypothesis"

func show_station(title: String) -> void:
    action_label.text = "E  Open %s" % title
```

- [ ] **Step 5: Wire without changing coordinator behavior**

Replace direct `StationHint.text` assignments in `main.gd` with the two prompt methods. Preserve persistence and error labels. Add a short `0.12`-second fade/scale tween when modal panels become visible, but never block input or alter their signal timing.

- [ ] **Step 6: Run GREEN and commit**

Expected: all suites pass and keyboard assertions remain green.

```powershell
git add apps/incident-room/resources/ui apps/incident-room/scenes/ui apps/incident-room/scenes/main/main.tscn apps/incident-room/scripts/presentation apps/incident-room/tests/test_panel_contracts.gd
git commit -m "feat: apply the Cozy Toy Office interface"
```

---

### Task 7: Visual capture, acceptance, performance, and distribution verification

**Files:**
- Create: `apps/incident-room/scripts/development/capture_visuals.gd`
- Create: `apps/incident-room/tests/test_visual_overhaul_acceptance.gd`
- Modify: `apps/incident-room/scripts/development/verify_project.ps1`
- Modify: `apps/incident-room/README.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: the complete polished game from Tasks 1-6.
- Produces: deterministic visual screenshots under ignored `dist/visual-checks`, artifact-size evidence, and acceptance coverage proving the candidate journey is unchanged.

- [ ] **Step 1: Add acceptance assertions**

The new suite must complete the existing evidence-based and unsupported-choice paths, then additionally assert the polished room loads, the player visual exposes idle/walk, all three landmarks load, all panels share the theme, and no domain script references `assets/third_party`.

- [ ] **Step 2: Run RED if any integration contract is incomplete**

Expected: GREEN only when Tasks 1-6 are fully integrated; otherwise fix the producing task before continuing.

- [ ] **Step 3: Add deterministic visual capture**

Create `capture_visuals.gd` that loads `main.tscn`, advances to the room with the existing public coordinator methods, waits two rendered frames, captures the root viewport texture, and writes `user://visual-checks/room.png`. Add capture points for title, room, each station modal, and summary; copy them into ignored `dist/visual-checks` from PowerShell after a successful run.

- [ ] **Step 4: Run complete verification**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/build_web.ps1
```

Expected: all suites pass; Web HTML, JavaScript, WASM, and PCK are nonempty; added compressed download is below 20 MB.

- [ ] **Step 5: Inspect visual evidence and keyboard journey**

Inspect every generated PNG at original detail. Launch the Windows project and the local Web server, then complete the entire flow using keyboard controls. Record any clipping, blocked trigger, unreadable text, missing animation, flicker, or frame-rate regression as a failing acceptance item and fix it in its owning task.

- [ ] **Step 6: Update documentation**

Document asset acquisition, provenance, the selected packs, how to regenerate assets, visual verification, Web-size result, and the fact that the overhaul changes presentation only. Update the root status to describe the Cozy Toy Office build after verification.

- [ ] **Step 7: Commit the verified overhaul**

```powershell
git add README.md apps/incident-room/README.md apps/incident-room/scripts/development apps/incident-room/tests/test_visual_overhaul_acceptance.gd
git commit -m "test: verify the Cozy Toy Office overhaul"
```

---

### Task 8: Railway redeployment and final synchronization

**Files:**
- Modify: `apps/incident-room/README.md`
- Modify: `docs/superpowers/specs/2026-07-16-godot-cozy-toy-office-visual-overhaul-design.md`
- Modify: `docs/superpowers/plans/2026-07-16-godot-cozy-toy-office-visual-overhaul.md`

**Interfaces:**
- Consumes: verified `apps/incident-room/dist/railway-web` staging bundle.
- Produces: updated `vibeproof-web` Railway deployment and synchronized `origin/main`.

- [ ] **Step 1: Deploy the exact verified staging bundle**

```powershell
railway up apps/incident-room/dist/railway-web --path-as-root --no-gitignore --service vibeproof-web --environment production --ci
```

Expected: `Deploy complete` without changing the existing five non-game services.

- [ ] **Step 2: Verify production artifacts**

Check `https://vibeproof-web-production.up.railway.app/`, `/index.wasm`, and `/index.pck`; require `200`, `application/wasm` for WASM, and content lengths matching the verified local staging bundle. Confirm Railway reports `SUCCESS` and `RUNNING` for `vibeproof-web`.

- [ ] **Step 3: Mark documentation implemented**

Record the implementation date, public URL, final Web sizes, suite count, visual checks, and any explicit human-browser limitation in the design, plan, and application README.

- [ ] **Step 4: Final verification and documentation commit**

Run the full verifier and Web build one final time, then:

```powershell
git add apps/incident-room/README.md docs/superpowers/specs/2026-07-16-godot-cozy-toy-office-visual-overhaul-design.md docs/superpowers/plans/2026-07-16-godot-cozy-toy-office-visual-overhaul.md
git commit -m "docs: publish the Cozy Toy Office build"
```

- [ ] **Step 5: Reconcile and push main safely**

```powershell
git fetch origin
git merge-base --is-ancestor origin/main main
git push origin main
```

If the ancestor check fails, fetch and rebase while preserving concurrent work; never force-push. Finish only when `main` and `origin/main` resolve to the same commit and `git status --short` is empty.
