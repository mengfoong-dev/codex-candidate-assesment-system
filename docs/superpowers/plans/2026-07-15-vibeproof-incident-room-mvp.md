# VibeProof Incident Room MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package a three-to-five-minute Godot Incident Room prototype that runs the controlled homepage-latency assessment, captures structured evidence automatically, evaluates transparent deterministic criteria, and renders a Proof Replay.

**Architecture:** Keep scenario data, event validation, state transitions, scoring, replay construction, and persistence independent from the 3D room. A non-autoload `SessionController` is the only facade used by presentation code. Build a complete primitive vertical slice before adding curated CC0 art, prompts, audio, or the time-boxed chibi character.

**Tech Stack:** Godot 4.7.1 Standard, GDScript, Compatibility renderer, JSON scenario data, JSONL session logs, built-in Godot controls and 3D nodes, a small first-party headless test runner, and PowerShell for reproducible tool/asset acquisition.

## Global Constraints

- The project root is exactly `apps/incident-room/`.
- Use Godot 4.7.1 Standard with GDScript and the Compatibility renderer.
- Target Windows x86_64 first; web export remains a stretch goal after every desktop acceptance check passes.
- The complete core flow must work offline with no backend, database, account, live LLM, arbitrary code execution, or candidate repository access.
- Keep exactly one incident, room, role, and player. Do not add multiplayer/networking, combat, inventory, quests, skill trees, NPC schedules, dialogue trees, voice/cutscenes, facial customization, a production recruiter dashboard, mobile builds, or validated/automated hiring claims.
- Use simple fixed lighting and materials; do not add dynamic lighting systems, reflections, post-processing, or high-end shaders.
- Capture only the structured assessment events defined below. Do not capture video, microphone audio, facial expressions, voice, raw operating-system input, unrelated keystrokes, pointer paths, or private reasoning.
- The room is an office-first colorful toy diorama with a smaller diagnostics corner and a fixed elevated orthographic three-quarter camera.
- Movement, elapsed time, camera control, station order, prompt count, and interaction count are never scored in isolation.
- Keys `1`, `2`, and `3` must expose the same evidence as walking to stations, so game navigation is optional.
- Do not use extracted or copied Overcooked, Pokemon, or other commercial-game assets, branding, maps, UI, audio, or characters.
- Runtime code must not read from repository `docs/`, `tools/`, `skills/`, `.codex/`, or `docs/archive/`.
- Session events append to `user://vibeproof/<session-id>/events.jsonl`; final summaries write to `user://vibeproof/<session-id>/summary.json`.
- Persistence failure must preserve in-memory events, show a recording warning, and allow completion.
- Display criteria as met, missed, excluded, clear, or warning with cited evidence. Never display an employment pass/fail verdict.
- Only zero-cost, clearly licensed runtime assets may be committed. Record every third-party source/runtime file in both `assets/third_party/manifest.json` and `THIRD_PARTY_NOTICES.md`; generated Godot `*.import` metadata is committed for reproducibility but excluded from provenance inventory.
- Commit every Godot-generated `*.gd.uid` beside its matching script and every generated `*.import` beside its curated asset. Do not add either pattern to `.gitignore`.
- Distribute the pinned Godot MIT license and its bundled third-party copyright/license inventory beside the Windows executable; asset attribution never replaces engine attribution.
- Preserve unrelated worktree state. Stage explicit paths; never stage `docs/hackathon/codex-usage/sessions.csv` or `.superpowers/` with implementation commits.
- Before every commit, inspect `git diff --cached --name-only`; if it contains anything outside that task's explicit `git add` list, stop and preserve it instead of committing mixed work.

## Two-Day Execution Gate

- Day 1 exit criterion: Tasks 1-11 pass with primitives and support a complete title-to-replay flow. Task 8 may run alongside the sequential Task 2-7 domain branch, and Tasks 9/10 may run alongside one another after the facade is stable, only in isolated worktrees created with `superpowers:using-git-worktrees`. In a shared worktree, execute all tasks sequentially. The integration owner cherry-picks task commits in numeric order and runs the auto-discovered full suite after each join.
- Day 2 priority: finish scenario/replay defects first, then spend at most two hours on Task 12 assets and polish, preserving at least two hours for Task 13 verification, export, and a visible playthrough.
- Under schedule pressure cut, in order: imported character/animation, nonessential decoration, sounds, ambient animation/lighting polish, web export, optional rationale. Never cut the briefing, three evidence surfaces, hypothesis capture/revision, verification, final submission, automatic event log, or Proof Replay.
- If the primitive full flow is not green by the Day 1 exit, do not begin optional asset work. The Windows desktop build is the only release target for this two-day MVP.

## Planned File Structure

```text
apps/incident-room/
|-- project.godot                         # Engine, renderer, window, and input settings
|-- export_presets.cfg                    # Windows x86_64 release export
|-- .gitignore                            # Godot cache, local test output, and packaged builds
|-- .gitattributes                        # Stable LF bytes for pinned engine notice hashes
|-- README.md                             # Setup, controls, verification, and responsible-use notice
|-- THIRD_PARTY_NOTICES.md                # Human-readable provenance and license record
|-- licenses/
|   |-- GODOT_LICENSE.txt                 # Pinned Godot MIT license
|   `-- GODOT_COPYRIGHT.txt               # Bundled third-party notices for the pinned engine
|-- assets/
|   |-- first_party/                      # Original icon/material resources if needed
|   `-- third_party/
|       |-- manifest.json                 # Machine-checkable inventory
|       |-- kaykit_furniture/
|       |-- kaykit_space/
|       |-- kenney_input/
|       |-- kenney_audio/
|       `-- chibi/
|-- data/scenarios/homepage_latency_v1.json
|-- scenes/
|   |-- main/main.tscn
|   |-- player/player.tscn
|   |-- room/incident_room.tscn
|   |-- stations/station_trigger.tscn
|   `-- ui/
|       |-- title_screen.tscn
|       |-- briefing_panel.tscn
|       |-- hud.tscn
|       |-- hypothesis_panel.tscn
|       |-- observability_panel.tscn
|       |-- developer_panel.tscn
|       |-- release_panel.tscn
|       `-- replay_panel.tscn
|-- scripts/
|   |-- domain/
|   |   |-- scenario_loader.gd
|   |   |-- event_schema.gd
|   |   |-- scenario_state.gd
|   |   |-- scoring_rules.gd
|   |   `-- replay_builder.gd
|   |-- persistence/
|   |   |-- session_store.gd
|   |   `-- event_logger.gd
|   |-- presentation/
|   |   |-- session_controller.gd
|   |   |-- input_setup.gd
|   |   |-- player_controller.gd
|   |   |-- station_trigger.gd
|   |   |-- interaction_controller.gd
|   |   |-- room_builder.gd
|   |   |-- asset_decorator.gd
|   |   |-- main.gd
|   |   `-- ui/
|   |       |-- title_screen.gd
|   |       |-- briefing_panel.gd
|   |       |-- hud.gd
|   |       |-- hypothesis_panel.gd
|   |       |-- observability_panel.gd
|   |       |-- developer_panel.gd
|   |       |-- release_panel.gd
|   |       `-- replay_panel.gd
|   `-- development/
|       |-- verify_project.ps1
|       `-- fetch_assets.ps1
`-- tests/
    |-- run_tests.gd
    |-- test_support.gd
    |-- fakes/fake_session_store.gd
    |-- fixtures/assessment_fixtures.gd
    |-- test_scenario_loader.gd
    |-- test_event_schema.gd
    |-- test_event_logger.gd
    |-- test_scenario_state.gd
    |-- test_scoring_rules.gd
    |-- test_replay_builder.gd
    |-- test_session_controller.gd
    |-- test_player_controller.gd
    |-- test_interaction_controller.gd
    |-- test_briefing_hypothesis_ui.gd
    |-- test_station_panels.gd
    |-- test_release_replay_ui.gd
    |-- test_main_flow.gd
    `-- test_asset_manifest.gd
```

## Frozen IDs and Interfaces

Use these IDs unchanged across JSON, events, scoring, UI, tests, and replay:

```text
scenario                 homepage_latency / version 1.0.0 (file homepage_latency_v1.json)
stations                 observability_wall, developer_desk, release_console
artifacts                metrics_overview, application_logs, homepage_trace, homepage_orchestrator
hypotheses/root causes   redis_degradation, database_slowdown, cpu_saturation,
                         sequential_independent_calls, insufficient_evidence
remediations             parallelize_confirmed_independent_calls, scale_cpu,
                         improve_redis_hit_rate, rewrite_system, collect_more_evidence
AI                       prompt safe_concurrency_prompt, response safe_concurrency_response_v1,
                         model scripted_offline_v1
AI dispositions          accept_immediately, verify_then_adapt, reject_suggestion
AI verification          calls_independent, failure_handling_considered
tests/validations         correctness_regression, p95_latency
rollback                 restore_sequential_orchestration, rollback_release, no_rollback
expected impact          lower_p95_preserve_correctness, increase_cpu_headroom,
                         increase_redis_hit_rate, unknown_impact
risks                    dependency_order, partial_failure_behavior, downstream_rate_limits,
                         shared_state_race, none_identified
assumptions              calls_are_independent, downstreams_support_concurrency,
                         no_required_ordering, none
```

`SessionController` is the presentation facade:

```gdscript
signal session_started(session_id: String)
signal state_changed(snapshot: Dictionary)
signal event_recorded(event: Dictionary)
signal recording_warning(message: String)
signal submission_rejected(errors: PackedStringArray)
signal replay_ready(view_model: Dictionary)

func configure(scenario: Dictionary, store: RefCounted, clock: Callable, elapsed_clock: Callable, session_id_factory: Callable) -> void
func begin_session(session_id_override: String = "") -> Dictionary
func record_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary
func view_evidence(artifact_id: String, evidence_type: String) -> Dictionary
func revise_hypothesis(hypothesis_id: String, confidence: int, trigger_evidence_ids: Array[String]) -> Dictionary
func run_scripted_ai(prompt_id: String) -> Array[Dictionary]
func disposition_ai(response_id: String, option_id: String, verification_ids: Array[String]) -> Dictionary
func execute_test(test_id: String, subject_remediation_id: String) -> Dictionary
func submit_final(submission: Dictionary) -> Dictionary
func get_snapshot() -> Dictionary
func get_events() -> Array[Dictionary]
```

Every event uses this envelope:

```gdscript
{
    "event_schema_version": "1.0.0",
    "event_id": "session-test:000001",
    "session_id": "session-test",
    "scenario_id": "homepage_latency",
    "scenario_version": "1.0.0",
    "sequence": 1,
    "event_type": "assessment_opened",
    "actor": "system",
    "occurred_at": "2026-07-15T08:00:00Z",
    "elapsed_active_ms": 0,
    "payload": {
        "attempt": 1,
        "presentation_id": "godot_incident_room",
        "notice_version": "v1"
    }
}
```

---

### Task 1: Pin the Toolchain, Scaffold the Project, and Load the Scenario

**Files:**
- Create: `apps/incident-room/project.godot`
- Create: `apps/incident-room/export_presets.cfg`
- Create: `apps/incident-room/.gitignore`
- Create: `apps/incident-room/.gitattributes`
- Create: `apps/incident-room/README.md`
- Create: `apps/incident-room/THIRD_PARTY_NOTICES.md`
- Create: `apps/incident-room/licenses/GODOT_LICENSE.txt`
- Create: `apps/incident-room/licenses/GODOT_COPYRIGHT.txt`
- Create: `apps/incident-room/data/scenarios/homepage_latency_v1.json`
- Create: `apps/incident-room/scripts/domain/scenario_loader.gd`
- Create: `apps/incident-room/scripts/development/verify_project.ps1`
- Create: `apps/incident-room/tests/test_support.gd`
- Create: `apps/incident-room/tests/run_tests.gd`
- Create: `apps/incident-room/tests/test_scenario_loader.gd`

**Interfaces:**
- Consumes: Godot 4.7.1 executable and export templates installed outside the repository.
- Produces: `ScenarioLoader.load_file(path: String) -> Dictionary` returning `{ok, scenario, errors}`, the reusable headless test runner, and a fail-fast import/test/UID verification command.

- [ ] **Step 1: Install and verify Godot 4.7.1 Standard outside the repository**

Run in PowerShell:

```powershell
$ErrorActionPreference = 'Stop'
$toolRoot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1'
$downloadRoot = Join-Path $env:TEMP 'vibeproof-godot-4.7.1'
New-Item -ItemType Directory -Force -Path $toolRoot,$downloadRoot | Out-Null

$editorZip = Join-Path $downloadRoot 'Godot_v4.7.1-stable_win64.exe.zip'
$templatesTpz = Join-Path $downloadRoot 'Godot_v4.7.1-stable_export_templates.tpz'
Invoke-WebRequest 'https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_win64.exe.zip' -OutFile $editorZip
Invoke-WebRequest 'https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz' -OutFile $templatesTpz

if ((Get-FileHash $editorZip -Algorithm SHA512).Hash -ne 'A6B02C527C18BA9936E63562032701432B2DC57D98D6483CEACCB00FE14AF16AF5773AE8A55E7B4D614EDF121C4D9E420D870F804EDB1DAC16362298A01CE6C4') { throw 'Godot editor checksum mismatch' }
if ((Get-FileHash $templatesTpz -Algorithm SHA512).Hash -ne 'AFCC83D8D3D298038F19C58744A0D660FA75DD4BAA33CB55D1011BB2565A2A8C2381728924564CB909E37C205A23F21B521B23BD057993AFD43AE4DA0B2F9D47') { throw 'Godot templates checksum mismatch' }

Expand-Archive -LiteralPath $editorZip -DestinationPath $toolRoot -Force
$templatesZip = Join-Path $downloadRoot 'templates.zip'
Copy-Item -LiteralPath $templatesTpz -Destination $templatesZip -Force
$templatesExtracted = Join-Path $downloadRoot 'templates-extracted'
Expand-Archive -LiteralPath $templatesZip -DestinationPath $templatesExtracted -Force
$templatesTarget = Join-Path $env:APPDATA 'Godot\export_templates\4.7.1.stable'
New-Item -ItemType Directory -Force -Path $templatesTarget | Out-Null
Copy-Item -Path (Join-Path $templatesExtracted 'templates\*') -Destination $templatesTarget -Recurse -Force
$windowsTemplate = Join-Path $templatesTarget 'windows_release_x86_64.exe'
if (-not (Test-Path -LiteralPath $windowsTemplate -PathType Leaf) -or (Get-Item -LiteralPath $windowsTemplate).Length -le 0) { throw 'Windows x86_64 release template was not installed correctly' }

$godot = Join-Path $toolRoot 'Godot_v4.7.1-stable_win64_console.exe'
& $godot --version
if ($LASTEXITCODE -ne 0) { throw 'Godot version check failed' }
```

Expected: output begins with `4.7.1.stable` and both checksum checks complete without throwing.

- [ ] **Step 2: Add the minimal Compatibility project and export configuration**

Use `apply_patch` to add `project.godot` with these exact settings:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="VibeProof Incident Room"
run/main_scene="res://scenes/main/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
renderer/rendering_method.web="gl_compatibility"
gl_compatibility/driver.windows="opengl3_angle"
gl_compatibility/fallback_to_native=true
environment/defaults/default_clear_color=Color(0.055, 0.071, 0.11, 1)
```

Use this Windows export preset:

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="data/scenarios/*.json,licenses/*.txt"
exclude_filter="tests/*,scripts/development/*"
export_path="dist/windows/VibeProofIncidentRoom.exe"
script_export_mode=2

[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
```

Add `.godot/`, `dist/`, `test-output/`, and `*.tmp` to the project `.gitignore`. Do not ignore Godot-generated `*.gd.uid` or `*.import` sidecars: commit them beside their matching scripts/assets so references and importer settings remain reproducible, while excluding `*.import` from the third-party provenance manifest. Add `.gitattributes` with exact lines `licenses/GODOT_LICENSE.txt text eol=lf` and `licenses/GODOT_COPYRIGHT.txt text eol=lf`; this keeps the pinned byte hashes stable even when the local Git configuration normally checks text out as CRLF. In the project README, record the pinned executable path, the two headless commands, controls, the offline/scripted-AI boundary, the human-review notice, and the requirement to ship the notice/license files beside the executable.

Download the two engine notice files from the exact pinned release tag and reject either hash mismatch:

```powershell
$ErrorActionPreference = 'Stop'
$licenseDir = Join-Path $PWD 'prototypes\godot-incident-room\licenses'
New-Item -ItemType Directory -Force -Path $licenseDir | Out-Null
$godotLicense = Join-Path $licenseDir 'GODOT_LICENSE.txt'
$godotCopyright = Join-Path $licenseDir 'GODOT_COPYRIGHT.txt'
Invoke-WebRequest 'https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/LICENSE.txt' -OutFile $godotLicense
Invoke-WebRequest 'https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/COPYRIGHT.txt' -OutFile $godotCopyright
if ((Get-FileHash $godotLicense -Algorithm SHA256).Hash -ne 'B0435E3B3E4E55238F05F4B306F30524A1B2E20147810D436EAA554FA6855C80') { throw 'Godot license hash mismatch' }
if ((Get-FileHash $godotCopyright -Algorithm SHA256).Hash -ne 'CB1980C88089573BCACD7221D777C689BB8BBD778799F24C27FCA0FE5F774D6D') { throw 'Godot copyright inventory hash mismatch' }
```

Use `apply_patch` to create `THIRD_PARTY_NOTICES.md` with a `Godot Engine 4.7.1` section naming the Godot Engine contributors and Juan Linietsky/Ariel Manzur, linking the pinned `LICENSE.txt` and `COPYRIGHT.txt` sources above, stating the engine is MIT-licensed, and directing distributors to keep both local license files with the build. Task 12 appends asset sections without replacing this engine section.

- [ ] **Step 3: Write the failing loader test and reusable test runner**

The loader test must assert the frozen ID, version, three stations, four artifacts, every stable fact ID, five root-cause choices, scripted model label, two required validation IDs, and nine scoring criteria:

```gdscript
extends RefCounted

const ScenarioLoader = preload("res://scripts/domain/scenario_loader.gd")
const TestSupport = preload("res://tests/test_support.gd")

func run(_tree: SceneTree) -> Array[String]:
    var t := TestSupport.new()
    var result := ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(result.ok, "scenario should load: %s" % result.errors)
    if result.ok:
        var scenario: Dictionary = result.scenario
        t.assert_equal(scenario.scenario_id, "homepage_latency", "scenario id")
        t.assert_equal(scenario.scenario_version, "1.0.0", "scenario version")
        t.assert_equal(scenario.stations.map(func(item): return item.station_id), ["observability_wall", "developer_desk", "release_console"], "station ids")
        t.assert_equal(scenario.artifacts.size(), 4, "artifact count")
        t.assert_equal(scenario.submission_options.root_causes.size(), 5, "root-cause count")
        t.assert_equal(scenario.ai_interaction.response.model_label, "scripted_offline_v1", "scripted AI label")
        t.assert_equal(scenario.submission_options.required_validation_test_ids, ["correctness_regression", "p95_latency"], "required validations")
    return t.failures
```

Use this reusable support object:

```gdscript
extends RefCounted

var failures: Array[String] = []

func assert_true(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func assert_false(value: bool, message: String) -> void:
    assert_true(not value, message)

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])

func assert_has_keys(value: Dictionary, keys: Array[String], message: String) -> void:
    for key in keys:
        if not value.has(key):
            failures.append("%s: missing key %s" % [message, key])
```

Make `run_tests.gd` discover top-level `test_*.gd` files so parallel tasks never edit a central suite registry:

```gdscript
extends SceneTree

func _initialize() -> void:
    call_deferred("_run_all")

func _run_all() -> void:
    var failure_count := 0
    var suite_files := PackedStringArray()
    for file_name in DirAccess.get_files_at("res://tests"):
        if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_support.gd":
            suite_files.append(file_name)
    suite_files.sort()
    for file_name in suite_files:
        var suite_script: Script = load("res://tests/" + file_name)
        if suite_script == null:
            failure_count += 1
            push_error("%s: suite could not be loaded" % file_name)
            continue
        var suite_instance: RefCounted = suite_script.new()
        if not suite_instance.has_method("run"):
            failure_count += 1
            push_error("%s: suite has no run(tree) method" % file_name)
            continue
        var suite_failures: Array[String] = suite_instance.run(self)
        for failure in suite_failures:
            failure_count += 1
            push_error("%s: %s" % [file_name, failure])
    if failure_count > 0:
        print("TESTS FAILED: %d failures" % failure_count)
        quit(1)
    else:
        print("TESTS PASSED: %d suites" % suite_files.size())
        quit(0)
```

Create `scripts/development/verify_project.ps1` as the one green-suite command used by later tasks. It must start Godot's editor import path before tests so Godot 4.7.1 generates stable script UID sidecars, then fail if any project/test script lacks its sibling `.gd.uid`:

```powershell
[CmdletBinding()]
param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot '..\..'),
    [string]$GodotPath = (Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
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
```

- [ ] **Step 4: Run the test to verify it fails**

Run:

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot executable not found: $godot" }
& $godot --headless --path apps/incident-room --script res://tests/run_tests.gd
if ($LASTEXITCODE -eq 0) { throw 'Expected the missing scenario contract test to fail' }
```

Expected: non-zero exit because `scenario_loader.gd` or the scenario file does not exist yet.

- [ ] **Step 5: Implement the loader and versioned scenario**

Implement this loader contract:

```gdscript
class_name ScenarioLoader
extends RefCounted

const REQUIRED_KEYS: Array[String] = [
    "schema_version", "scenario_id", "scenario_version", "title", "role",
    "brief", "stations", "artifacts", "hypotheses", "ai_interaction",
    "tests", "submission_options", "scoring", "notices"
]

static func load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Scenario file not found: %s" % path])}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Scenario file could not be opened: %s" % path])}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Scenario root must be a JSON object"])}
    var scenario: Dictionary = parsed
    var errors := _normalize_integer_fields(scenario)
    errors.append_array(validate_scenario(scenario))
    return {"ok": errors.is_empty(), "scenario": scenario if errors.is_empty() else {}, "errors": errors}

static func validate_scenario(scenario: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for key in REQUIRED_KEYS:
        if not scenario.has(key):
            errors.append("Missing scenario key: %s" % key)
    if scenario.get("scenario_id", "") != "homepage_latency":
        errors.append("Unsupported scenario id")
    if scenario.get("scenario_version", "") != "1.0.0":
        errors.append("Unsupported scenario version")
    if scenario.get("schema_version", "") != "1.0.0":
        errors.append("Unsupported scenario schema version")
    if typeof(scenario.get("artifacts", null)) != TYPE_ARRAY or scenario.get("artifacts", []).size() != 4:
        errors.append("Scenario must define exactly four artifacts")
    errors.append_array(_validate_unique_ids_and_references(scenario))
    return errors

static func _validate_unique_ids_and_references(scenario: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var station_ids := _collect_unique_ids(scenario.get("stations", []), "station_id", "station", errors)
    var hypothesis_ids := _collect_unique_ids(scenario.get("hypotheses", []), "hypothesis_id", "hypothesis", errors)
    var artifact_ids := _collect_unique_ids(scenario.get("artifacts", []), "artifact_id", "artifact", errors)
    var test_ids := _collect_unique_ids(scenario.get("tests", []), "test_id", "test", errors)
    var fact_ids: Dictionary = {}
    for artifact_value in scenario.get("artifacts", []):
        if typeof(artifact_value) != TYPE_DICTIONARY:
            errors.append("Artifact entries must be objects")
            continue
        var artifact: Dictionary = artifact_value
        if not station_ids.has(str(artifact.get("station_id", ""))):
            errors.append("Artifact references unknown station: %s" % artifact.get("station_id", ""))
        if not ["metrics", "logs", "trace", "source_code"].has(artifact.get("evidence_type", "")):
            errors.append("Artifact has unsupported evidence type: %s" % artifact.get("evidence_type", ""))
        var local_fact_ids := _collect_unique_ids(artifact.get("facts", []), "fact_id", "fact", errors)
        for fact_id in local_fact_ids:
            if fact_ids.has(fact_id):
                errors.append("Duplicate fact id: %s" % fact_id)
            fact_ids[fact_id] = true
    var ai: Dictionary = scenario.get("ai_interaction", {})
    for artifact_id in ai.get("prompt", {}).get("referenced_context_ids", []):
        if not artifact_ids.has(artifact_id):
            errors.append("AI prompt references unknown artifact: %s" % artifact_id)
    _collect_unique_ids(ai.get("dispositions", []), "option_id", "AI disposition", errors)
    var options: Dictionary = scenario.get("submission_options", {})
    var remediation_ids := _collect_unique_ids(options.get("remediations", []), "option_id", "remediation", errors)
    for root_cause in options.get("root_causes", []):
        if typeof(root_cause) == TYPE_DICTIONARY and not hypothesis_ids.has(str(root_cause.get("option_id", ""))):
            errors.append("Root cause has no matching hypothesis: %s" % root_cause.get("option_id", ""))
    for group in ["root_causes", "expected_impacts", "risks", "assumptions", "rollbacks"]:
        _collect_unique_ids(options.get(group, []), "option_id", group, errors)
    for test_id in options.get("required_validation_test_ids", []):
        if not test_ids.has(test_id):
            errors.append("Required validation references unknown test: %s" % test_id)
    for test_value in scenario.get("tests", []):
        if typeof(test_value) != TYPE_DICTIONARY:
            continue
        for remediation_id in test_value.get("results_by_remediation", {}):
            if not remediation_ids.has(remediation_id):
                errors.append("Test result references unknown remediation: %s" % remediation_id)
    _collect_unique_ids(scenario.get("scoring", {}).get("criteria", []), "criterion_id", "criterion", errors)
    return errors

static func _collect_unique_ids(items: Variant, id_field: String, label: String, errors: PackedStringArray) -> Dictionary:
    var ids: Dictionary = {}
    if typeof(items) != TYPE_ARRAY:
        errors.append("%s collection must be an array" % label.capitalize())
        return ids
    for item_value in items:
        if typeof(item_value) != TYPE_DICTIONARY:
            errors.append("%s entries must be objects" % label.capitalize())
            continue
        var item: Dictionary = item_value
        var item_id := str(item.get(id_field, ""))
        if item_id.is_empty():
            errors.append("%s is missing %s" % [label.capitalize(), id_field])
        elif ids.has(item_id):
            errors.append("Duplicate %s id: %s" % [label, item_id])
        else:
            ids[item_id] = true
    return ids
```

Implement `_normalize_integer_fields` before structural validation because Godot's JSON parser represents JSON numbers as floats. Accept only finite, mathematically integral numeric values at these paths, rewrite them with `int(...)`, and otherwise add a validation error: every `stations[*].quick_key`, `ai_interaction.response.latency_ms`, and `scoring.criteria[*].configured_points`. Then validate quick keys are exactly `1`, `2`, and `3` without duplicates, latency is non-negative, and configured points match the nine frozen Task 5 values. The loader test asserts all three normalized field groups have `TYPE_INT`; add a fractional quick-key fixture that fails instead of truncating.

`_validate_unique_ids_and_references` rejects duplicate station, hypothesis, artifact, fact, AI option, test, choice, or criterion IDs. It also rejects an unknown station on an artifact, unknown AI context artifact, unknown required validation test, and a test-result remediation that does not resolve to a configured choice. Add negative fixtures for a duplicate fact, dangling AI artifact, dangling required test, and dangling remediation result.

The JSON file must contain the frozen IDs, the exact 180 ms to 850 ms brief, CPU 35%, healthy database and recommendation service, Redis hit rate 42%, sequential trace waits, the sequential TypeScript-style `await` example, the scripted safe-concurrency response, and structured submission options. Stations are `{station_id, title, quick_key}` objects; hypotheses are `{hypothesis_id, label}` objects. Each artifact includes `artifact_id`, `station_id`, `evidence_type`, `title`, `content: Array[String]`, and stable `facts` entries containing `fact_id` and `label`. Supporting evidence and hypothesis triggers reference `fact_id`; do not include the hidden answer in candidate-visible artifact titles.

Use these exact artifact facts:

| Artifact | Fact ID | Candidate-visible label |
|---|---|---|
| `metrics_overview` | `homepage_p95_increased` | Homepage p95 is 850 ms, previously 180 ms. |
| `metrics_overview` | `cpu_not_saturated` | CPU utilization is 35%. |
| `metrics_overview` | `database_healthy` | Database health checks are healthy. |
| `metrics_overview` | `recommendation_service_healthy` | Recommendation service health checks are healthy. |
| `metrics_overview` | `redis_hit_rate_low` | Redis hit rate is 42%. |
| `application_logs` | `requests_complete_without_errors` | Homepage requests complete without application errors. |
| `application_logs` | `downstream_calls_successful` | Downstream service calls return successfully. |
| `application_logs` | `no_database_timeout` | No database timeout appears in the logs. |
| `application_logs` | `no_cpu_exhaustion` | No CPU-exhaustion signal appears in the logs. |
| `homepage_trace` | `downstream_calls_sequential_in_trace` | Several downstream calls appear one after another. |
| `homepage_trace` | `downstream_waits_accumulate` | Their waiting times accumulate into homepage latency. |
| `homepage_orchestrator` | `sequential_awaits_in_code` | The orchestration awaits profile, recommendations, and notices sequentially. |
| `homepage_orchestrator` | `calls_are_independent_in_code` | The three lookups share only the user ID and do not consume one another's results. |
| `homepage_orchestrator` | `required_ordering_must_remain` | Authentication and final rendering must remain ordered around the lookups. |

The source-code content is this readable TypeScript-style example:

```typescript
await requireAuthenticatedUser(userId);
const profile = await getProfile(userId);
const recommendations = await getRecommendations(userId);
const notices = await getNotices(userId);
return renderHomepage({ profile, recommendations, notices });
```

Use this exact scripted interaction and never call a network model:

```json
{
  "prompt": {
    "prompt_id": "safe_concurrency_prompt",
    "text": "How could these calls be made concurrent safely, and what assumptions should be checked?",
    "referenced_context_ids": ["homepage_orchestrator"]
  },
  "response": {
    "response_id": "safe_concurrency_response_v1",
    "model_label": "scripted_offline_v1",
    "latency_ms": 0,
    "status": "ok",
    "text": "Run only confirmed-independent calls concurrently, preserve required ordering, and consider partial failure handling."
  },
  "dispositions": [
    {"option_id": "accept_immediately", "disposition": "accepted", "verification_ids": []},
    {"option_id": "verify_then_adapt", "disposition": "modified", "verification_ids": ["calls_independent", "failure_handling_considered"]},
    {"option_id": "reject_suggestion", "disposition": "rejected", "verification_ids": []}
  ]
}
```

Each test contains `test_id`, `title`, `expected_result`, and `results_by_remediation`, a dictionary keyed by every remediation ID whose values are `{actual_result, status}`. For `parallelize_confirmed_independent_calls`, `correctness_regression` returns actual `12 of 12 scripted fixtures passed.` with status `passed`, and `p95_latency` returns actual `Scripted p95 is 310 ms and the error rate is unchanged.` with status `passed`. Every other remediation returns status `unavailable` and the actual result `No scripted result is available for this proposal; select or describe an appropriate validation plan.` Mark every result as a scripted prototype simulation in the UI; never imply arbitrary candidate code ran.

Populate `submission_options.root_causes`, `remediations`, `expected_impacts`, `risks`, `assumptions`, and `rollbacks` as arrays of `{ "option_id": "<frozen-id>", "label": "<candidate-visible copy>" }`; add `required_validation_test_ids` as the exact two-ID string array. Populate `scoring.criteria` with objects containing `criterion_id`, `dimension`, `kind`, `configured_points`, and candidate-visible `label` for the nine Task 5 rules; executable conditions remain in `ScoringRules`, not JSON strings. Use these notices verbatim:

```json
{
  "human_review": "This prototype supports human review and does not make an employment decision.",
  "limitations": "Results are scenario-specific evidence, not a validated psychometric judgment.",
  "navigation": "Navigation speed and game-control performance are not scored."
}
```

- [ ] **Step 6: Verify import and the passing loader test**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Project import, UID, or loader verification failed' }
```

Expected: both commands exit `0`; the test runner prints `TESTS PASSED: 1 suites`.

- [ ] **Step 7: Commit the independently loadable project contract**

```powershell
git add -- apps/incident-room/project.godot apps/incident-room/export_presets.cfg apps/incident-room/.gitignore apps/incident-room/.gitattributes apps/incident-room/README.md apps/incident-room/THIRD_PARTY_NOTICES.md apps/incident-room/licenses apps/incident-room/data/scenarios/homepage_latency_v1.json apps/incident-room/scripts/domain/scenario_loader.gd apps/incident-room/scripts/domain/scenario_loader.gd.uid apps/incident-room/scripts/development/verify_project.ps1 apps/incident-room/tests
git commit --only -m "chore: scaffold incident room scenario and tests" -- apps/incident-room/project.godot apps/incident-room/export_presets.cfg apps/incident-room/.gitignore apps/incident-room/.gitattributes apps/incident-room/README.md apps/incident-room/THIRD_PARTY_NOTICES.md apps/incident-room/licenses apps/incident-room/data/scenarios/homepage_latency_v1.json apps/incident-room/scripts/domain/scenario_loader.gd apps/incident-room/scripts/domain/scenario_loader.gd.uid apps/incident-room/scripts/development/verify_project.ps1 apps/incident-room/tests
```

### Task 2: Define and Validate Structured Assessment Events

**Files:**
- Create: `apps/incident-room/scripts/domain/event_schema.gd`
- Create: `apps/incident-room/tests/fixtures/assessment_fixtures.gd`
- Create: `apps/incident-room/tests/test_event_schema.gd`

**Interfaces:**
- Consumes: Frozen scenario and event IDs from Task 1.
- Produces: `EventSchema.build(context, event_type, actor, payload) -> Dictionary`, `EventSchema.validate(event) -> PackedStringArray`, and `EventSchema.to_json_line(event) -> String`.

- [ ] **Step 1: Write failing tests for the envelope and per-event payload requirements**

Test a valid `evidence_viewed` event and reject a `final_submission` without `supporting_evidence_ids`, `expected_impact_id`, `risk_ids`, `assumption_ids`, `validation_test_ids`, `rollback_id`, and `final_confidence`:

```gdscript
var context := {
    "session_id": "session-test", "scenario_id": "homepage_latency",
    "scenario_version": "1.0.0", "sequence": 1,
    "occurred_at": "2026-07-15T08:00:00Z", "elapsed_active_ms": 0
}
var event := EventSchema.build(context, "evidence_viewed", "candidate", {
    "artifact_id": "homepage_trace", "evidence_type": "trace",
    "station_id": "observability_wall",
    "fact_ids": ["downstream_calls_sequential_in_trace", "downstream_waits_accumulate"]
})
t.assert_equal(EventSchema.validate(event), PackedStringArray(), "valid evidence event")
t.assert_equal(event.event_id, "session-test:000001", "deterministic event id")

context.sequence = 2
var invalid := EventSchema.build(context, "final_submission", "candidate", {"root_cause_id": "sequential_independent_calls"})
t.assert_true(EventSchema.validate(invalid).size() >= 7, "incomplete submission must be rejected")
```

Also cover all minimum event types: `assessment_opened`, `evidence_viewed`, `hypothesis_recorded`, `hypothesis_revised`, `ai_prompt_submitted`, `ai_response_received`, `ai_suggestion_dispositioned`, `test_executed`, `decision_recorded`, `final_submission`, and `technical_error`. Keep `search_performed` and `tool_invoked` valid but unused for schema compatibility. Add a malformed-envelope case whose `payload` is a string and assert that validation returns an error without raising or aborting the suite.

- [ ] **Step 2: Run the test to verify it fails**

Run the headless test command. Expected: non-zero exit because `EventSchema` is missing.

- [ ] **Step 3: Implement the schema with explicit required payload fields**

Use this event registry and construction logic:

```gdscript
class_name EventSchema
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const BASE_FIELDS: Array[String] = [
    "event_schema_version", "event_id", "session_id", "sequence",
    "scenario_id", "scenario_version", "event_type", "actor",
    "occurred_at", "elapsed_active_ms", "payload"
]
const REQUIRED_PAYLOAD := {
    "assessment_opened": ["attempt", "presentation_id", "notice_version"],
    "evidence_viewed": ["artifact_id", "evidence_type", "station_id", "fact_ids"],
    "search_performed": ["query", "scope", "result_count"],
    "hypothesis_recorded": ["version", "hypothesis_id", "hypothesis_text", "confidence", "evidence_refs"],
    "hypothesis_revised": ["previous_version", "new_version", "previous_hypothesis_id", "new_hypothesis_id", "new_hypothesis_text", "previous_confidence", "confidence", "trigger_evidence_ids"],
    "ai_prompt_submitted": ["prompt_id", "prompt_text", "referenced_context_ids"],
    "ai_response_received": ["response_id", "prompt_event_id", "model_label", "latency_ms", "status", "response_text"],
    "ai_suggestion_dispositioned": ["response_id", "option_id", "disposition", "verification_ids"],
    "test_executed": ["test_id", "subject_remediation_id", "expected_result", "actual_result", "status"],
    "tool_invoked": ["tool_type", "parameters", "outcome"],
    "decision_recorded": ["action_id", "action_text", "rationale", "risk_ids", "assumption_ids"],
    "final_submission": ["root_cause_id", "supporting_evidence_ids", "remediation_id", "expected_impact_id", "risk_ids", "assumption_ids", "validation_test_ids", "rollback_id", "final_confidence", "rationale"],
    "technical_error": ["component", "error_code", "message", "recoverable", "affected_artifact_ids", "excluded_criterion_ids"]
}

static func build(context: Dictionary, event_type: String, actor: String, payload: Dictionary) -> Dictionary:
    var sequence := int(context.sequence)
    return {
        "event_schema_version": SCHEMA_VERSION,
        "event_id": "%s:%06d" % [context.session_id, sequence],
        "session_id": context.session_id,
        "sequence": sequence,
        "scenario_id": context.scenario_id,
        "scenario_version": context.scenario_version,
        "event_type": event_type,
        "actor": actor,
        "occurred_at": context.occurred_at,
        "elapsed_active_ms": int(context.elapsed_active_ms),
        "payload": payload.duplicate(true)
    }

static func validate(event: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for field in BASE_FIELDS:
        if not event.has(field):
            errors.append("Missing event field: %s" % field)
    var event_type_value: Variant = event.get("event_type", null)
    if typeof(event_type_value) != TYPE_STRING:
        errors.append("event_type must be a string")
        return errors
    var event_type: String = event_type_value
    if not REQUIRED_PAYLOAD.has(event_type):
        errors.append("Unsupported event type: %s" % event_type)
        return errors
    var payload_value: Variant = event.get("payload", null)
    if typeof(payload_value) != TYPE_DICTIONARY:
        errors.append("payload must be a dictionary")
        return errors
    var payload: Dictionary = payload_value
    for field in REQUIRED_PAYLOAD[event_type]:
        if not payload.has(field):
            errors.append("%s missing payload field: %s" % [event_type, field])
    if int(event.get("sequence", 0)) < 1:
        errors.append("Event sequence must be positive")
    if not ["system", "candidate", "scripted_assistant"].has(event.get("actor", "")):
        errors.append("Unsupported actor")
    for field in ["previous_confidence", "confidence", "final_confidence"]:
        if payload.has(field):
            var confidence: Variant = payload[field]
            if typeof(confidence) != TYPE_INT or confidence < 0 or confidence > 100:
                errors.append("%s must be an integer between 0 and 100" % field)
    return errors

static func to_json_line(event: Dictionary) -> String:
    return JSON.stringify(event)
```

Complete `validate` with these exact invariants: schema version equals `1.0.0`; session/scenario IDs, version, event ID, event type, actor, and timestamp are non-empty strings; `event_id` equals `<session_id>:<sequence padded to six digits>`; `elapsed_active_ms` and AI `latency_ms` are non-negative integers; `payload` is a dictionary; every required array field is an array of strings; and every confidence value is an integer in `0..100`. Validate enums for actors (`system`, `candidate`, `scripted_assistant`), evidence types (`metrics`, `logs`, `trace`, `source_code`), AI response statuses (`ok`, `error`), AI dispositions (`accepted`, `modified`, `rejected`), and test statuses (`passed`, `failed`, `unavailable`). Enforce actor ownership: `assessment_opened` and `technical_error` are `system`; `ai_response_received` is `scripted_assistant`; every other supported event is `candidate`. Add one failing assertion for each enum/ownership case plus string confidence, negative elapsed/latency, and a mismatched event ID. Scenario-aware code must also reject a `technical_error.excluded_criterion_ids` value that is not one of the nine configured criteria.

All final-submission keys exist even when arrays or `rationale` are empty; incompleteness is recorded for transparent scoring rather than rejected at the schema boundary. Do not infer or generate rationale content.

Create `assessment_fixtures.gd` as a `RefCounted` test helper exposing `event(event_type, payload, sequence, actor := "candidate")`, `correct_submission()`, `correct_path_events()`, `correct_initial_path_events()`, `renumber(events)`, `result_by_id(report, criterion_id)`, `all_results_have_valid_refs(results, events)`, `sequences_are_sorted(rows)`, `rows_in_category(replay, category)`, and `rows_for_artifact(replay, artifact_id)`. Declare every exposed helper method `static` so suites can consistently call `Fixtures.correct_path_events()` and the other methods without constructing an instance. `event` delegates to `EventSchema.build` with session `session-test`, scenario `homepage_latency` version `1.0.0`, timestamp `2026-07-15T08:00:00Z`, and `elapsed_active_ms = (sequence - 1) * 1000`. `correct_submission` returns the exact Task 11 dictionary. `correct_path_events` uses this exact order: opening; wrong Redis hypothesis; metrics; trace; revision to sequential calls; code; AI prompt; AI response; verified/adapted disposition; both concurrency-subject test events; decision; final submission. `correct_initial_path_events` replaces the wrong hypothesis/revision pair with one correct initial hypothesis. `renumber` first maps every old event ID to its new sequence-derived ID, then rewrites sequence, event ID, elapsed time, and all event-ID payload references such as `ai_response_received.prompt_event_id`. `result_by_id` scans `report.criterion_results` and calls `assert(false, ...)` if the ID is absent. The reference helper indexes events by ID and walks every JSON Pointer segment to prove it resolves; the row helpers are pure filters/order checks.

- [ ] **Step 4: Run all tests and verify the new suite passes**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Event-schema import, UID, or test verification failed' }
```

Expected: `TESTS PASSED: 2 suites`.

- [ ] **Step 5: Commit the event contract**

```powershell
git add -- apps/incident-room/scripts/domain/event_schema.gd apps/incident-room/scripts/domain/event_schema.gd.uid apps/incident-room/tests/fixtures/assessment_fixtures.gd apps/incident-room/tests/fixtures/assessment_fixtures.gd.uid apps/incident-room/tests/test_event_schema.gd apps/incident-room/tests/test_event_schema.gd.uid
git commit --only -m "feat: define structured assessment events" -- apps/incident-room/scripts/domain/event_schema.gd apps/incident-room/scripts/domain/event_schema.gd.uid apps/incident-room/tests/fixtures/assessment_fixtures.gd apps/incident-room/tests/fixtures/assessment_fixtures.gd.uid apps/incident-room/tests/test_event_schema.gd apps/incident-room/tests/test_event_schema.gd.uid
```

### Task 3: Persist Append-Only Sessions with an In-Memory Fallback

**Files:**
- Create: `apps/incident-room/scripts/persistence/session_store.gd`
- Create: `apps/incident-room/scripts/persistence/event_logger.gd`
- Create: `apps/incident-room/tests/fakes/fake_session_store.gd`
- Create: `apps/incident-room/tests/test_event_logger.gd`

**Interfaces:**
- Consumes: `EventSchema.build`, `EventSchema.validate`, and `EventSchema.to_json_line`.
- Produces: append-only disk storage and `EventLogger` methods `start`, `prepare`, `append_prepared`, `record`, `write_summary`, `get_events`, and `has_persistence_failure`; the first persistence failure also creates one audit-only in-memory `technical_error`.

- [ ] **Step 1: Write failing sequence, JSONL, summary, and failure-fallback tests**

Inject a deterministic fake store, clock, and session ID:

```gdscript
var store := FakeSessionStore.new()
var timestamps := ["2026-07-15T08:00:00Z", "2026-07-15T08:00:01Z", "2026-07-15T08:00:02Z", "2026-07-15T08:00:03Z"]
var clock := func() -> String: return timestamps.pop_front()
var logger := EventLogger.new(store, clock, func() -> int: return 0, func() -> String: return "session-test")

var opened := logger.start("homepage_latency", "1.0.0", "session-test")
var viewed := logger.record("evidence_viewed", "candidate", {
    "artifact_id": "homepage_trace", "evidence_type": "trace",
    "station_id": "observability_wall",
    "fact_ids": ["downstream_calls_sequential_in_trace", "downstream_waits_accumulate"]
})
t.assert_equal(opened.event.sequence, 1, "opening sequence")
t.assert_equal(viewed.event.sequence, 2, "monotonic sequence")
t.assert_equal(store.event_lines.size(), 2, "two append-only JSONL lines")
t.assert_equal(JSON.parse_string(store.event_lines[1]).event_id, "session-test:000002", "serialized event")

store.fail_events = true
var failed := logger.record("evidence_viewed", "candidate", {
    "artifact_id": "homepage_orchestrator", "evidence_type": "source_code",
    "station_id": "developer_desk",
    "fact_ids": ["sequential_awaits_in_code", "calls_are_independent_in_code", "required_ordering_must_remain"]
})
t.assert_true(failed.accepted, "valid event remains accepted in memory")
t.assert_false(failed.persisted, "failed write is reported")
t.assert_equal(failed.follow_up_events.size(), 1, "first persistence failure creates one audit event")
t.assert_equal(failed.follow_up_events[0].event_type, "technical_error", "failure is auditable")
t.assert_true(logger.has_persistence_failure(), "logger records persistence warning")
t.assert_equal(logger.get_events().size(), 4, "failed write and technical error remain in memory")
```

Also assert that an invalid event does not consume a sequence number, later failures do not duplicate the persistence technical error, invalid session IDs (`../escape`, `a/b`, and strings over 64 characters) perform no filesystem calls, and `summary.json` uses the exact session directory.

- [ ] **Step 2: Run the tests to verify they fail**

Expected: non-zero exit because store/logger files are missing.

- [ ] **Step 3: Implement the disk store and injectable logger**

`SessionStore` owns only filesystem operations:

```gdscript
class_name SessionStore
extends RefCounted

var base_dir := "user://vibeproof"

func _init(base_dir_override: String = "") -> void:
    if not base_dir_override.is_empty():
        base_dir = base_dir_override

func begin_session(session_id: String) -> Error:
    if not _is_valid_session_id(session_id):
        return ERR_INVALID_PARAMETER
    return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir.path_join(session_id)))

func append_event_line(session_id: String, line: String) -> Error:
    if not _is_valid_session_id(session_id):
        return ERR_INVALID_PARAMETER
    var path := base_dir.path_join(session_id).path_join("events.jsonl")
    var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
    var file := FileAccess.open(path, mode)
    if file == null:
        return FileAccess.get_open_error()
    if mode == FileAccess.READ_WRITE:
        file.seek_end()
    file.store_line(line)
    file.flush()
    return file.get_error()

func write_summary(session_id: String, summary: Dictionary) -> Error:
    if not _is_valid_session_id(session_id):
        return ERR_INVALID_PARAMETER
    var path := base_dir.path_join(session_id).path_join("summary.json")
    var temporary_path := path + ".tmp"
    if FileAccess.file_exists(path):
        return ERR_ALREADY_EXISTS
    var file := FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(summary, "  "))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
        return write_error
    var rename_error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temporary_path),
        ProjectSettings.globalize_path(path)
    )
    if rename_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
    return rename_error

func _is_valid_session_id(session_id: String) -> bool:
    var regex := RegEx.new()
    return regex.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$") == OK and regex.search(session_id) != null
```

Call `_is_valid_session_id` at the start of all three store operations, not only directory creation. Add a fake-store post-open write-error mode and assert the logger still returns `persisted:false`. Summary writes are atomic: a failed temporary write or rename leaves no canonical `summary.json`, and a second final summary never overwrites the first. The `flush`/`get_error` implementation is the real-store protection for errors after a successful open.

`EventLogger.start` records sequence 1 as `assessment_opened` with actor `system`, attempt 1, presentation `godot_incident_room`, and notice `v1`. The production UTC clock is `Time.get_datetime_string_from_system(true, false) + "Z"`; the elapsed clock subtracts the session-start `Time.get_ticks_msec()` value and never drives scoring. `prepare` constructs the next event with sequence `events.size() + 1`, the injected clocks, and no mutation of memory or disk. `append_prepared` rejects a stale/wrong-session event, validates it, appends a deep copy to memory, and attempts the store write. `record` is the convenience composition `append_prepared(prepare(...))`. An append returns exactly:

```gdscript
{
    "accepted": true,
    "event": event,
    "persisted": error == OK,
    "error_code": error,
    "follow_up_events": follow_up_events
}
```

`append_prepared` accepts only the logger's current session/scenario, the exact next sequence and derived event ID, and a schema-valid envelope. A stale prepared event returns `accepted:false` and consumes no sequence. When `begin_session`, event append, or summary writing fails, set a sticky `persistence_failed` flag. On the first such failure, construct the next valid `technical_error` with actor `system`, `component:"persistence"`, the first error code/message, `recoverable:true`, and empty affected-artifact/excluded-criterion arrays; append it directly to memory without attempting another disk write, and expose it in `follow_up_events`. Even if directory creation fails, `start` retains the valid opening event plus that technical error in memory and the session remains usable. `write_summary` returns `{persisted, error_code, follow_up_events}`. Never remove an accepted in-memory event and never retry by overwriting the JSONL file.

- [ ] **Step 4: Run all suites and inspect a real temporary JSONL file**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Persistence import, UID, or test verification failed' }
```

Use a real `SessionStore` rooted at `user://vibeproof-test/run-<ticks>-<16 random hex>` in one test and parse every non-empty line with `JSON.parse_string`. Generate that per-run root before constructing the store so repeated suite runs never reuse JSONL. Expected: all lines parse, sequences are `[1, 2]`, failed summary writes leave no canonical file, and all suites pass.

- [ ] **Step 5: Commit persistence and its test fake**

```powershell
git add -- apps/incident-room/scripts/persistence apps/incident-room/tests/fakes apps/incident-room/tests/test_event_logger.gd apps/incident-room/tests/test_event_logger.gd.uid
git commit --only -m "feat: persist append-only assessment sessions" -- apps/incident-room/scripts/persistence apps/incident-room/tests/fakes apps/incident-room/tests/test_event_logger.gd apps/incident-room/tests/test_event_logger.gd.uid
```

### Task 4: Model Investigation State and Rebuild It from Events

**Files:**
- Create: `apps/incident-room/scripts/domain/scenario_state.gd`
- Create: `apps/incident-room/tests/test_scenario_state.gd`

**Interfaces:**
- Consumes: validated event dictionaries.
- Produces: `ScenarioState.new(known_fact_ids)`, `validate_event`, `apply_event`, `rebuild`, unique artifact/fact tracking, hypothesis versioning, one-time finalization, and `snapshot()`.

- [ ] **Step 1: Write failing tests for state transitions and validation**

Cover these exact behaviors:

```gdscript
const Fixtures = preload("res://tests/fixtures/assessment_fixtures.gd")

var state := ScenarioState.new([
    "homepage_p95_increased", "cpu_not_saturated", "database_healthy",
    "recommendation_service_healthy", "redis_hit_rate_low",
    "requests_complete_without_errors", "downstream_calls_successful",
    "no_database_timeout", "no_cpu_exhaustion",
    "downstream_calls_sequential_in_trace", "downstream_waits_accumulate",
    "sequential_awaits_in_code", "calls_are_independent_in_code",
    "required_ordering_must_remain"
])
state.apply_event(Fixtures.event("hypothesis_recorded", {"version": 1, "hypothesis_id": "redis_degradation", "hypothesis_text": "Redis degradation", "confidence": 65, "evidence_refs": []}, 1))
state.apply_event(Fixtures.event("evidence_viewed", {"artifact_id": "homepage_trace", "evidence_type": "trace", "station_id": "observability_wall", "fact_ids": ["downstream_calls_sequential_in_trace", "downstream_waits_accumulate"]}, 2))
state.apply_event(Fixtures.event("evidence_viewed", {"artifact_id": "homepage_trace", "evidence_type": "trace", "station_id": "observability_wall", "fact_ids": ["downstream_calls_sequential_in_trace", "downstream_waits_accumulate"]}, 3))
state.apply_event(Fixtures.event("hypothesis_revised", {"previous_version": 1, "new_version": 2, "previous_hypothesis_id": "redis_degradation", "new_hypothesis_id": "sequential_independent_calls", "new_hypothesis_text": "Sequential independent calls", "previous_confidence": 65, "confidence": 90, "trigger_evidence_ids": ["downstream_calls_sequential_in_trace"]}, 4))

t.assert_equal(state.viewed_artifact_ids.keys(), ["homepage_trace"], "artifact set is unique")
t.assert_true(state.viewed_fact_ids.has("downstream_calls_sequential_in_trace"), "viewed facts are indexed")
t.assert_equal(state.events.size(), 4, "duplicate views remain in timeline")
t.assert_equal(state.hypotheses.size(), 2, "revision adds a version")
t.assert_equal(state.hypotheses[1].hypothesis_id, "sequential_independent_calls", "revision linkage")

var errors := state.validate_submission(Fixtures.correct_submission())
t.assert_equal(errors, PackedStringArray(), "complete structured submission")
var incomplete := Fixtures.correct_submission()
incomplete.supporting_evidence_ids = []
t.assert_equal(state.validate_submission(incomplete), PackedStringArray(), "empty evidence remains auditable and scoreable")
```

Also reject confidence outside `0..100`, unknown final fact IDs, unseen revision-trigger facts, stale hypothesis versions, a second final submission, and candidate-domain mutations after completion. Known but unviewed final citations are accepted so the scoring warning remains reachable. Assert that `rebuild(events)` produces the same snapshot as applying the events live.

- [ ] **Step 2: Run the state test and confirm failure**

Expected: missing `ScenarioState` causes a non-zero test exit.

- [ ] **Step 3: Implement event application and submission validation**

Use explicit event-type branches:

```gdscript
class_name ScenarioState
extends RefCounted

var events: Array[Dictionary] = []
var known_fact_ids: Dictionary = {}
var session_id := ""
var scenario_id := ""
var scenario_version := ""
var phase := "title"
var viewed_artifact_ids: Dictionary = {}
var viewed_fact_ids: Dictionary = {}
var hypotheses: Array[Dictionary] = []
var ai_dispositions_by_response_id: Dictionary = {}
var executed_tests_by_id: Dictionary = {}
var final_submission: Dictionary = {}
var technical_errors: Array[Dictionary] = []
var completed := false

func _init(input_known_fact_ids: Array[String] = []) -> void:
    for fact_id in input_known_fact_ids:
        known_fact_ids[fact_id] = true

func apply_event(event: Dictionary) -> void:
    events.append(event.duplicate(true))
    var payload: Dictionary = event.payload
    match event.event_type:
        "assessment_opened":
            session_id = event.session_id
            scenario_id = event.scenario_id
            scenario_version = event.scenario_version
            phase = "briefing"
        "evidence_viewed":
            viewed_artifact_ids[payload.artifact_id] = true
            for fact_id in payload.fact_ids:
                viewed_fact_ids[fact_id] = payload.artifact_id
        "hypothesis_recorded":
            hypotheses.append({"version": payload.version, "hypothesis_id": payload.hypothesis_id, "confidence": payload.confidence, "evidence_refs": payload.evidence_refs.duplicate(), "source_event_id": event.event_id})
            phase = "investigation"
        "hypothesis_revised":
            hypotheses.append({"version": payload.new_version, "hypothesis_id": payload.new_hypothesis_id, "confidence": payload.confidence, "evidence_refs": payload.trigger_evidence_ids.duplicate(), "source_event_id": event.event_id})
        "ai_suggestion_dispositioned":
            ai_dispositions_by_response_id[payload.response_id] = payload.duplicate(true)
        "test_executed":
            executed_tests_by_id[payload.test_id] = payload.duplicate(true)
        "final_submission":
            final_submission = payload.duplicate(true)
            completed = true
            phase = "completed"
        "technical_error":
            technical_errors.append(event.duplicate(true))

func validate_submission(submission: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for field in ["root_cause_id", "supporting_evidence_ids", "remediation_id", "expected_impact_id", "risk_ids", "assumption_ids", "validation_test_ids", "rollback_id", "final_confidence", "rationale"]:
        if not submission.has(field):
            errors.append("Missing submission field: %s" % field)
    var confidence: Variant = submission.get("final_confidence", null)
    if typeof(confidence) != TYPE_INT or confidence < 0 or confidence > 100:
        errors.append("Final confidence must be an integer between 0 and 100")
    for fact_id in submission.get("supporting_evidence_ids", []):
        if not known_fact_ids.has(fact_id):
            errors.append("Unknown supporting fact: %s" % fact_id)
    return errors

func snapshot() -> Dictionary:
    return {
        "events": events.duplicate(true),
        "session_id": session_id,
        "scenario_id": scenario_id,
        "scenario_version": scenario_version,
        "phase": phase,
        "viewed_artifact_ids": viewed_artifact_ids.duplicate(true),
        "viewed_fact_ids": viewed_fact_ids.duplicate(true),
        "hypotheses": hypotheses.duplicate(true),
        "ai_dispositions_by_response_id": ai_dispositions_by_response_id.duplicate(true),
        "executed_tests_by_id": executed_tests_by_id.duplicate(true),
        "final_submission": final_submission.duplicate(true),
        "technical_errors": technical_errors.duplicate(true),
        "completed": completed
    }
```

Add `validate_event(event)` to enforce phase order, exact hypothesis versions, earlier viewed trigger facts, one-time completion, and post-completion candidate immutability; a valid system `technical_error` may still be applied after completion. Add `rebuild(input_events)` to clear session-derived values (but retain the configured known-fact index), then reduce events in ascending sequence order. Do not delete duplicate evidence events from `events`.

- [ ] **Step 4: Run all tests**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Scenario-state import, UID, or test verification failed' }
```

Expected: state tests pass and earlier suites remain green.

- [ ] **Step 5: Commit the state model**

```powershell
git add -- apps/incident-room/scripts/domain/scenario_state.gd apps/incident-room/scripts/domain/scenario_state.gd.uid apps/incident-room/tests/test_scenario_state.gd apps/incident-room/tests/test_scenario_state.gd.uid
git commit --only -m "feat: model incident investigation state" -- apps/incident-room/scripts/domain/scenario_state.gd apps/incident-room/scripts/domain/scenario_state.gd.uid apps/incident-room/tests/test_scenario_state.gd apps/incident-room/tests/test_scenario_state.gd.uid
```

### Task 5: Evaluate Six Positive Criteria, Three Warnings, and Fair Exclusions

**Files:**
- Create: `apps/incident-room/scripts/domain/scoring_rules.gd`
- Create: `apps/incident-room/tests/test_scoring_rules.gd`

**Interfaces:**
- Consumes: scenario JSON plus ordered raw events.
- Produces: `ScoringRules.evaluate(scenario: Dictionary, events: Array[Dictionary]) -> Dictionary` with criterion results, dimension results, point context, and no pass/fail field.

- [ ] **Step 1: Write failing correct-path, warning-path, exclusion, and idempotence tests**

Build a canonical correct event sequence: wrong initial Redis hypothesis, metrics, trace, revision, code, scripted AI verification, both test events, decision, and correct final submission. Assert:

```gdscript
const Fixtures = preload("res://tests/fixtures/assessment_fixtures.gd")

var report := ScoringRules.evaluate(scenario, Fixtures.correct_path_events())
t.assert_equal(report.positive_points_earned, 60, "six positive criteria")
t.assert_equal(report.positive_points_available, 60, "full denominator")
t.assert_equal(report.warning_points_applied, 0, "no warnings")
t.assert_false(report.has("pass"), "no employment pass/fail")
t.assert_true(Fixtures.all_results_have_valid_refs(report.criterion_results, Fixtures.correct_path_events()), "every result cites auditable evidence")

var repeated := Fixtures.correct_path_events()
repeated.insert(5, repeated[2].duplicate(true))
Fixtures.renumber(repeated)
t.assert_equal(ScoringRules.evaluate(scenario, repeated).net_points, report.net_points, "repeat views do not add credit")

var already_correct := Fixtures.correct_initial_path_events()
var correct_report := ScoringRules.evaluate(scenario, already_correct)
t.assert_equal(Fixtures.result_by_id(correct_report, "revised_after_contradiction").status, "excluded", "correct initial hypothesis is not penalized")
t.assert_equal(correct_report.positive_points_available, 50, "excluded rule adjusts denominator")
```

Add separate assertions for immediate unverified AI acceptance (`-10`), CPU diagnosis or scaling (`-10`), empty/unseen citations (`-15`), trace after decision, only one validation test, and a `technical_error` that excludes a named criterion.

- [ ] **Step 2: Run the scoring test to verify it fails**

Expected: missing `ScoringRules` produces a non-zero exit.

- [ ] **Step 3: Implement the exact rule registry and result shape**

Return each criterion in this exact shape:

```gdscript
{
    "criterion_id": "trace_before_change",
    "dimension": "evidence_use",
    "kind": "positive",
    "status": "satisfied",
    "configured_points": 10,
    "awarded_points": 10,
    "reason": "The homepage trace was viewed before the recorded change.",
    "evidence_refs": [{
        "event_id": "session-test:000003",
        "field_path": "/payload/artifact_id",
        "artifact_id": "homepage_trace",
        "fact_id": null
    }],
    "exclusion_reason": null
}
```

Implement these conditions exactly:

| Criterion | Kind | Points | Condition |
|---|---|---:|---|
| `trace_before_change` | positive | +10 | `homepage_trace` viewed before `decision_recorded` and the final remediation changes code. |
| `healthy_signals_used` | positive | +10 | Revision triggers or final citations contain `cpu_not_saturated` and at least one of `database_healthy` or `recommendation_service_healthy`. |
| `sequential_source_identified` | positive | +10 | `homepage_orchestrator` was viewed and final/revision evidence cites `sequential_awaits_in_code`. |
| `independence_checked` | positive | +10 | Before decision, either `verify_then_adapt` records `calls_independent`, or `homepage_orchestrator` was viewed and `decision_recorded.assumption_ids` contains `calls_are_independent`; the final submission also cites `calls_are_independent_in_code`, and final remediation is concurrency. |
| `dual_validation_selected` | positive | +10 | Both required `test_executed` events for the final remediation occur before final submission and both IDs appear in `validation_test_ids`. |
| `revised_after_contradiction` | positive | +10 | A non-root-cause hypothesis is revised to the correct root cause after a cited trace/code fact. Exclude when the initial hypothesis is already correct and never contradicted. |
| `unsupported_cpu_scaling` | warning | -10 | Root cause is `cpu_saturation` or remediation is `scale_cpu`. |
| `unverified_ai_acceptance` | warning | -10 | Last AI disposition before decision is `accept_immediately` with no later independence verification. |
| `diagnosis_without_evidence` | warning | -15 | Citations are empty, invalid, or refer only to facts from artifacts never viewed. |

For `trace_before_change`, the code-change remediation set is exactly `parallelize_confirmed_independent_calls` and `rewrite_system`; reviewing a trace can still earn evidence-use credit even when the final change is too broad. Use sequence ordering, never timestamps. An `excluded_criterion_ids` entry in any `technical_error` changes that result to `excluded`, awards zero, and cites the technical-error event. Compute:

```gdscript
{
    "criterion_results": results,
    "dimension_results": dimensions,
    "positive_points_earned": positive_earned,
    "positive_points_available": positive_available,
    "warning_points_applied": warning_points,
    "net_points": maxi(0, positive_earned + warning_points),
    "unscored_dimensions": ["problem_framing", "hypothesis_quality", "ai_direction", "communication"]
}
```

`dimension_results` contains the five scored dimensions (`investigation_strategy`, `evidence_use`, `ai_verification`, `adaptability`, `technical_conclusion`) with `status: "scored"`, earned/available points, and criterion IDs. It also contains `problem_framing`, `hypothesis_quality`, `ai_direction`, and `communication` with `status: "not_scored"`, zero points, and a short reason. A fixed scripted prompt must never create an AI-direction score.

Every criterion result, including `not_satisfied`, `not_triggered`, and `excluded`, has at least one valid event/field reference. For an absence-based result, cite the final-submission field that exposes the missing or conflicting claim and state the absent-event query in the result reason; a correct-initial-hypothesis exclusion cites the initial hypothesis, and a technical exclusion cites the `technical_error`. Tests must resolve every referenced event ID and JSON Pointer-style field path.

Do not add a threshold, rank, grade, hiring recommendation, personality label, or prediction.

- [ ] **Step 4: Run all suites and verify ordering invariance where rules permit it**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Scoring import, UID, or test verification failed' }
```

Expected: correct and plausible-incorrect paths pass; permutations of metrics/log/code views produce the same result when explicit before/after requirements remain satisfied.

- [ ] **Step 5: Commit transparent deterministic scoring**

```powershell
git add -- apps/incident-room/scripts/domain/scoring_rules.gd apps/incident-room/scripts/domain/scoring_rules.gd.uid apps/incident-room/tests/test_scoring_rules.gd apps/incident-room/tests/test_scoring_rules.gd.uid
git commit --only -m "feat: evaluate deterministic evidence criteria" -- apps/incident-room/scripts/domain/scoring_rules.gd apps/incident-room/scripts/domain/scoring_rules.gd.uid apps/incident-room/tests/test_scoring_rules.gd apps/incident-room/tests/test_scoring_rules.gd.uid
```

### Task 6: Build an Ordered and Evidence-Cited Proof Replay

**Files:**
- Create: `apps/incident-room/scripts/domain/replay_builder.gd`
- Create: `apps/incident-room/tests/test_replay_builder.gd`

**Interfaces:**
- Consumes: scenario, raw events, scoring report, and persistence status.
- Produces: `ReplayBuilder.build(scenario, events, scoring_report, persistence_status) -> Dictionary`.

- [ ] **Step 1: Write failing replay ordering, grouping, and required-section tests**

Pass shuffled events and assert ascending sequence rows, duplicate evidence rows, one enriched AI row with three source event IDs, one combined final decision row, technical errors, at most three static interview questions, and both notices:

```gdscript
const Fixtures = preload("res://tests/fixtures/assessment_fixtures.gd")

var ordered_events := Fixtures.correct_path_events()
ordered_events.insert(4, ordered_events[3].duplicate(true))
Fixtures.renumber(ordered_events)
var scoring_report := ScoringRules.evaluate(scenario, ordered_events)
var shuffled_events := ordered_events.duplicate(true)
shuffled_events.reverse()
var replay := ReplayBuilder.build(scenario, shuffled_events, scoring_report, "saved")
t.assert_equal(replay.replay_schema_version, "1.0.0", "replay schema")
t.assert_equal(replay.completion_status, "completed", "completion")
t.assert_true(Fixtures.sequences_are_sorted(replay.rows), "rows sort by sequence")
t.assert_equal(Fixtures.rows_in_category(replay, "ai").size(), 1, "AI chain is grouped")
t.assert_equal(Fixtures.rows_in_category(replay, "ai")[0].source_event_ids.size(), 3, "AI row cites prompt response disposition")
t.assert_equal(Fixtures.rows_for_artifact(replay, "homepage_trace").size(), 2, "duplicate views remain visible")
t.assert_true(replay.notices.human_review.contains("does not make an employment decision"), "human-review notice")
t.assert_true(replay.notices.limitations.contains("not a validated psychometric judgment"), "limitation notice")
```

- [ ] **Step 2: Run the replay test to verify it fails**

Expected: missing builder causes a non-zero exit.

- [ ] **Step 3: Implement the replay view model**

Return exactly these top-level keys:

```gdscript
{
    "replay_schema_version": "1.0.0",
    "session_id": session_id,
    "scenario_id": scenario.scenario_id,
    "scenario_version": scenario.scenario_version,
    "completion_status": "completed" if final_event != null else "incomplete",
    "duration_active_ms": last_elapsed_ms,
    "persistence_status": persistence_status,
    "dimension_results": scoring_report.dimension_results,
    "criterion_results": scoring_report.criterion_results,
    "hypotheses": hypotheses,
    "rows": rows,
    "final_submission": final_payload,
    "technical_errors": technical_errors,
    "suggested_interview_questions": capped_questions,
    "notices": {
        "human_review": "This prototype supports human review and does not make an employment decision.",
        "limitations": "Results are scenario-specific evidence, not a validated psychometric judgment."
    }
}
```

Each row contains `row_id`, anchor `sequence`, `elapsed_active_ms`, `category`, `title`, `detail`, `status`, `source_event_ids`, `artifact_ids`, `fact_ids`, and `criterion_ids`. Categories are `session`, `hypothesis`, `evidence`, `ai`, `verification`, `decision`, `submission`, and `technical_error`. Sort by anchor sequence only.

Create `capped_questions` by iterating deterministic static questions in criterion-registry order and stopping as soon as its size reaches three. For example: `What evidence would you gather before deciding to scale CPU?` Never call an LLM.

- [ ] **Step 4: Run all suites**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Replay import, UID, or test verification failed' }
```

Expected: every replay citation references a real event ID and all tests pass.

- [ ] **Step 5: Commit the Proof Replay builder**

```powershell
git add -- apps/incident-room/scripts/domain/replay_builder.gd apps/incident-room/scripts/domain/replay_builder.gd.uid apps/incident-room/tests/test_replay_builder.gd apps/incident-room/tests/test_replay_builder.gd.uid
git commit --only -m "feat: build proof replay view models" -- apps/incident-room/scripts/domain/replay_builder.gd apps/incident-room/scripts/domain/replay_builder.gd.uid apps/incident-room/tests/test_replay_builder.gd apps/incident-room/tests/test_replay_builder.gd.uid
```

### Task 7: Orchestrate a Complete Incident Session Behind One Facade

**Files:**
- Create: `apps/incident-room/scripts/presentation/session_controller.gd`
- Create: `apps/incident-room/tests/test_session_controller.gd`

**Interfaces:**
- Consumes: scenario, `EventLogger`, `ScenarioState`, `ScoringRules`, and `ReplayBuilder`.
- Produces: the frozen `SessionController` signals/commands and a complete non-visual assessment flow.

- [ ] **Step 1: Write a failing facade integration test**

Configure the controller with a loaded scenario and fake store. Drive the public commands in this order:

```gdscript
const Fixtures = preload("res://tests/fixtures/assessment_fixtures.gd")

var clock := func() -> String: return "2026-07-15T08:00:00Z"
var elapsed_clock := func() -> int: return 0
controller.configure(scenario, store, clock, elapsed_clock, func() -> String: return "session-test")
controller.begin_session("session-test")
controller.record_initial_hypothesis("redis_degradation", 65)
controller.view_evidence("metrics_overview", "metrics")
controller.view_evidence("homepage_trace", "trace")
controller.revise_hypothesis("sequential_independent_calls", 85, ["downstream_calls_sequential_in_trace"])
controller.view_evidence("homepage_orchestrator", "source_code")
var ai_events := controller.run_scripted_ai("safe_concurrency_prompt")
t.assert_equal(ai_events.size(), 2, "prompt and scripted response are recorded")
t.assert_equal(typeof(ai_events[1].payload.latency_ms), TYPE_INT, "configured JSON latency is normalized at the event boundary")
t.assert_equal(EventSchema.validate(ai_events[1]), PackedStringArray(), "scripted response satisfies event schema")
controller.disposition_ai("safe_concurrency_response_v1", "verify_then_adapt", ["calls_independent", "failure_handling_considered"])
controller.execute_test("correctness_regression", "parallelize_confirmed_independent_calls")
controller.execute_test("p95_latency", "parallelize_confirmed_independent_calls")
var result := controller.submit_final(Fixtures.correct_submission())

t.assert_true(result.ok, "complete session")
t.assert_equal(result.replay.completion_status, "completed", "replay is final")
t.assert_equal(result.scoring.positive_points_earned, 60, "correct evidence path")
t.assert_equal(store.summary.session_id, "session-test", "summary is written")
t.assert_equal(controller.get_events()[0].event_type, "assessment_opened", "automatic opening event")
```

Also test evidence before initial hypothesis, stale revision triggers, duplicate final submission, and a plausible wrong path. Add a distinct `fail_begin` fake-store case: `begin_session` still returns `ok:true`, current events are opening sequence one plus one persistence `technical_error`, `recording_warning` emits exactly once, and the session can still reach replay in memory. Later append/summary failures in that same session must not emit duplicate warning signals.

- [ ] **Step 2: Run the facade test to verify it fails**

Expected: missing controller causes a non-zero exit.

- [ ] **Step 3: Implement command validation and event emission**

`configure` deep-copies a loader-validated scenario, builds its artifact/fact/choice/criterion indexes, and retains the store plus deterministic callables needed to construct per-session `EventLogger` and `ScenarioState` instances. Reject `begin_session` before configuration or while a non-finalized session is active. After completion, `begin_session` creates fresh logger/state instances, resets sequence to one, and clears all prior-session in-memory events and warning state; a clean start emits only the new session's opening event. Apply/emit every event returned by `EventLogger.start`; if `start.persisted` is false or the logger's sticky failure flag is set, call `_emit_recording_warning_once()` before returning the still-usable session. A test override and every generated session ID must match `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`; reject separators, `..`, and invalid IDs before any store call. The production factory returns `session-<UTC YYYYMMDDTHHMMSSZ>-<16 lowercase hex characters>` from `Time` plus eight `Crypto` random bytes; complete two consecutive sessions in the facade test and assert distinct IDs, current-session-only events, and a second `assessment_opened` at sequence one.

Use a single private recording path:

```gdscript
func _record(event_type: String, actor: String, payload: Dictionary) -> Dictionary:
    var prepared := logger.prepare(event_type, actor, payload)
    var schema_errors := EventSchema.validate(prepared)
    if not schema_errors.is_empty():
        return {"ok": false, "errors": schema_errors}
    var state_errors := state.validate_event(prepared)
    if not state_errors.is_empty():
        return {"ok": false, "errors": state_errors}
    var result := logger.append_prepared(prepared)
    if not result.accepted:
        return {"ok": false, "errors": PackedStringArray([str(result.error_code)])}
    state.apply_event(result.event)
    event_recorded.emit(result.event)
    for follow_up_event in result.follow_up_events:
        state.apply_event(follow_up_event)
        event_recorded.emit(follow_up_event)
    state_changed.emit(state.snapshot())
    if not result.persisted:
        _emit_recording_warning_once()
    return {"ok": true, "event": result.event, "persisted": result.persisted}
```

Use the `EventLogger.prepare`/`append_prepared` pair from Task 3 so state validation and the persisted envelope operate on the same immutable event. A rejected prepared event must not consume a sequence number. `_emit_recording_warning_once` guards a per-session boolean, emits the frozen in-memory-continuation message at most once, and resets only when a clean new session begins; use it for begin, append, and summary failures.

`view_evidence` looks up the scenario artifact and logs all of its stable `fact_ids`. `run_scripted_ai` logs prompt and response events only; it constructs the response payload with `"latency_ms": int(configured_response.latency_ms)` even though the loader already normalized it, then requires `_record` to return `ok` for both events before returning them. `disposition_ai` is separate and must match the response's configured option/disposition/verification IDs. `execute_test` accepts only a configured test/remediation pair, selects that pair's configured result, includes `subject_remediation_id`, and labels it clearly as a prototype simulation. Hypothesis IDs, artifact/type pairs, AI IDs, test IDs, technical-error exclusion IDs, and every final-submission choice/fact ID are validated against the loaded scenario before `_record` is called. Known but unviewed final citations remain recordable so `diagnosis_without_evidence` can warn; revision triggers still require an earlier view. Presentation code reads normalized `int(station.quick_key)` values and scoring converts `configured_points` to `int` again at accumulation boundaries; no typed integer variable receives an unnormalized JSON value.

`begin_session` applies and emits the opening event followed by any persistence `follow_up_events`. `submit_final` validates the full key structure but records empty arrays so warnings remain auditable. It logs `decision_recorded` then `final_submission` exactly once, evaluates rules, builds replay using the logger's sticky persistence status, and attempts `summary.json`. If summary writing fails, apply/emit its follow-up technical event, rebuild the replay from the complete in-memory list with `memory_only`, emit the recording warning, and do not claim a saved summary. Emit `replay_ready` last and return `{ok, scoring, replay}`. `get_snapshot` merges the state snapshot with `persistence_status`; `get_events` returns deep copies from the logger.

Freeze `summary.json` to exactly these top-level keys and add a schema/assertion test:

```gdscript
{
    "summary_schema_version": "1.0.0",
    "session_id": replay.session_id,
    "scenario_id": replay.scenario_id,
    "scenario_version": replay.scenario_version,
    "completion_status": replay.completion_status,
    "persistence_status": replay.persistence_status,
    "event_count": logger.get_events().size(),
    "scoring_report": scoring,
    "replay": replay
}
```

- [ ] **Step 4: Run all domain and facade suites**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Facade import, UID, or test verification failed' }
```

Expected: one full correct path and one incorrect path complete without room or UI nodes; failure mode is `memory_only` rather than an aborted session.

- [ ] **Step 5: Commit the complete engine-light vertical slice**

```powershell
git add -- apps/incident-room/scripts/presentation/session_controller.gd apps/incident-room/scripts/presentation/session_controller.gd.uid apps/incident-room/scripts/persistence/event_logger.gd apps/incident-room/scripts/persistence/event_logger.gd.uid apps/incident-room/tests/test_session_controller.gd apps/incident-room/tests/test_session_controller.gd.uid
git commit --only -m "feat: orchestrate complete incident sessions" -- apps/incident-room/scripts/presentation/session_controller.gd apps/incident-room/scripts/presentation/session_controller.gd.uid apps/incident-room/scripts/persistence/event_logger.gd apps/incident-room/scripts/persistence/event_logger.gd.uid apps/incident-room/tests/test_session_controller.gd apps/incident-room/tests/test_session_controller.gd.uid
```

### Task 8: Build the Primitive Office, Fixed Camera, Player, and Accessible Station Interaction

**Files:**
- Create: `apps/incident-room/scenes/player/player.tscn`
- Create: `apps/incident-room/scenes/room/incident_room.tscn`
- Create: `apps/incident-room/scenes/stations/station_trigger.tscn`
- Create: `apps/incident-room/scripts/presentation/input_setup.gd`
- Create: `apps/incident-room/scripts/presentation/player_controller.gd`
- Create: `apps/incident-room/scripts/presentation/station_trigger.gd`
- Create: `apps/incident-room/scripts/presentation/interaction_controller.gd`
- Create: `apps/incident-room/scripts/presentation/room_builder.gd`
- Create: `apps/incident-room/tests/test_player_controller.gd`
- Create: `apps/incident-room/tests/test_interaction_controller.gd`

**Interfaces:**
- Consumes: no assessment-domain internals.
- Produces: a primitive office-first cutaway room, `station_requested(station_id)`, and player motion that is never recorded as assessment evidence.

- [ ] **Step 1: Write failing movement, camera, station, and quick-access tests**

Assert camera-relative normalized motion, a fixed orthographic camera, exactly three station IDs, nearest-station `E` behavior, and direct `1`/`2`/`3` requests. Assert no interaction class imports `EventLogger` or `ScoringRules`.

```gdscript
var direction := PlayerController.camera_relative_direction(Vector2(1, 0), Basis.IDENTITY)
t.assert_equal(direction, Vector3(1, 0, 0), "screen-right movement")
var forward := PlayerController.camera_relative_direction(Vector2(0, -1), Basis.IDENTITY)
t.assert_equal(forward, Vector3(0, 0, -1), "screen-up movement")

var room := RoomBuilder.build_room()
t.assert_equal(room.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "orthographic camera")
t.assert_equal(room.camera.size, 17.5, "fixed framing")
t.assert_equal(room.stations.map(func(s): return s.station_id), ["observability_wall", "developer_desk", "release_console"], "station ids")
```

- [ ] **Step 2: Run the presentation tests to verify failure**

Expected: missing world scripts/scenes produce a non-zero exit.

- [ ] **Step 3: Implement inputs, primitive player, and station requests**

`InputSetup.ensure_actions()` adds `move_left/right/forward/back`, `interact`, `quick_observability`, `quick_developer`, `quick_release`, `hypothesis`, and `pause` only when absent, using physical keys `A/D/W/S`, `E`, `1/2/3`, `H`, and `Escape`.

Use this player movement contract:

```gdscript
class_name PlayerController
extends CharacterBody3D

@export var speed := 4.2
var movement_enabled := false

func set_enabled(value: bool) -> void:
    movement_enabled = value
    if not value:
        velocity = Vector3.ZERO

static func camera_relative_direction(input: Vector2, camera_basis: Basis) -> Vector3:
    var right := camera_basis.x
    var forward := -camera_basis.z
    right.y = 0.0
    forward.y = 0.0
    return (right.normalized() * input.x + forward.normalized() * -input.y).normalized()

func _physics_process(_delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if movement_enabled else Vector2.ZERO
    var camera := get_viewport().get_camera_3d()
    var direction := camera_relative_direction(input, camera.global_basis) if camera else Vector3.ZERO
    velocity = direction * speed
    if not direction.is_zero_approx():
        rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.25)
    move_and_slide()
```

The station trigger exports `station_id` and `prompt_text`. `InteractionController` maintains nearby stations and emits `station_requested`; it never emits movement or timing events.

- [ ] **Step 4: Build the office-first primitive room and fixed camera**

The room builder creates a 16x11 floor, back/side cutaway walls, low partitions, office desks and chairs, one observability wall, one developer desk, one release console, collision, a directional light, and this camera:

```gdscript
var camera := Camera3D.new()
camera.transform = Transform3D(Basis.IDENTITY, Vector3(10.5, 14.0, 10.5)).looking_at(
    Vector3(0.0, 1.0, 0.0), Vector3.UP
)
camera.projection = Camera3D.PROJECTION_ORTHOGONAL
camera.size = 17.5
camera.near = 0.1
camera.far = 60.0
camera.keep_aspect = Camera3D.KEEP_HEIGHT
camera.current = true
```

Use a first-party capsule/sphere chibi fallback with a procedural movement bob. Keep every center-room prop below player-head height.

Use one cohesive first-party toy-diorama palette even before asset import: warm ivory floor `#E9DFC7`, mint office wall `#9ED7C5`, slate diagnostics floor `#334155`, navy outlines/UI `#172033`, observability cyan `#35C7E8`, developer violet `#8B6CEB`, release amber `#F6B94A`, success green `#56C596`, and warning coral `#F06A6A`. Use rough non-metallic materials, soft ambient fill, one shadow-casting directional light, emissive station rings in the three station colors, and floating text prompts. Do not add post-processing, dynamic camera effects, or visual information that exists only in color.

- [ ] **Step 5: Run import and presentation tests**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Presentation import, UID, or test verification failed' }
```

Expected: all suites pass. The main-scene smoke test is added in Task 11, after `main.tscn` exists.

- [ ] **Step 6: Commit the independently playable greybox world**

```powershell
git add -- apps/incident-room/scenes/player apps/incident-room/scenes/room apps/incident-room/scenes/stations apps/incident-room/scripts/presentation/input_setup.gd apps/incident-room/scripts/presentation/input_setup.gd.uid apps/incident-room/scripts/presentation/player_controller.gd apps/incident-room/scripts/presentation/player_controller.gd.uid apps/incident-room/scripts/presentation/station_trigger.gd apps/incident-room/scripts/presentation/station_trigger.gd.uid apps/incident-room/scripts/presentation/interaction_controller.gd apps/incident-room/scripts/presentation/interaction_controller.gd.uid apps/incident-room/scripts/presentation/room_builder.gd apps/incident-room/scripts/presentation/room_builder.gd.uid apps/incident-room/tests/test_player_controller.gd apps/incident-room/tests/test_player_controller.gd.uid apps/incident-room/tests/test_interaction_controller.gd apps/incident-room/tests/test_interaction_controller.gd.uid
git commit --only -m "feat: add fixed-camera office exploration" -- apps/incident-room/scenes/player apps/incident-room/scenes/room apps/incident-room/scenes/stations apps/incident-room/scripts/presentation/input_setup.gd apps/incident-room/scripts/presentation/input_setup.gd.uid apps/incident-room/scripts/presentation/player_controller.gd apps/incident-room/scripts/presentation/player_controller.gd.uid apps/incident-room/scripts/presentation/station_trigger.gd apps/incident-room/scripts/presentation/station_trigger.gd.uid apps/incident-room/scripts/presentation/interaction_controller.gd apps/incident-room/scripts/presentation/interaction_controller.gd.uid apps/incident-room/scripts/presentation/room_builder.gd apps/incident-room/scripts/presentation/room_builder.gd.uid apps/incident-room/tests/test_player_controller.gd apps/incident-room/tests/test_player_controller.gd.uid apps/incident-room/tests/test_interaction_controller.gd apps/incident-room/tests/test_interaction_controller.gd.uid
```

### Task 9: Add the Notice, Briefing, HUD, and Hypothesis Flow

**Files:**
- Create: `apps/incident-room/scenes/ui/title_screen.tscn`
- Create: `apps/incident-room/scenes/ui/briefing_panel.tscn`
- Create: `apps/incident-room/scenes/ui/hud.tscn`
- Create: `apps/incident-room/scenes/ui/hypothesis_panel.tscn`
- Create: `apps/incident-room/scripts/presentation/ui/title_screen.gd`
- Create: `apps/incident-room/scripts/presentation/ui/briefing_panel.gd`
- Create: `apps/incident-room/scripts/presentation/ui/hud.gd`
- Create: `apps/incident-room/scripts/presentation/ui/hypothesis_panel.gd`
- Create: `apps/incident-room/tests/test_briefing_hypothesis_ui.gd`

**Interfaces:**
- Consumes: scenario copy and state snapshots only.
- Produces: `start_requested`, `initial_hypothesis_submitted`, `hypothesis_revision_submitted`, and HUD methods for prompt, hypothesis, and recording-warning state.

- [ ] **Step 1: Write failing UI contract tests**

Instantiate each scene headlessly and assert:

```gdscript
t.assert_true(title.collection_notice.text.contains("structured in-game actions"), "collection notice")
t.assert_true(title.collection_notice.text.contains("navigation speed is not scored"), "navigation notice")
t.assert_true(title.collection_notice.text.contains("human review"), "human-review notice")
t.assert_equal(briefing.hypothesis_select.item_count, 5, "all initial hypotheses")
t.assert_equal(briefing.confidence_slider.min_value, 0, "confidence minimum")
t.assert_equal(briefing.confidence_slider.max_value, 100, "confidence maximum")
hypothesis.set_viewed_facts([{"fact_id": "cpu_not_saturated", "label": "CPU utilization is 35%."}])
t.assert_equal(hypothesis.trigger_select.item_count, 1, "revision triggers are viewed facts only")
```

Assert that the first actionable control receives keyboard focus whenever a panel opens and that Escape closes non-required panels.

- [ ] **Step 2: Run the UI test to verify failure**

Expected: missing scenes/scripts produce a non-zero exit.

- [ ] **Step 3: Implement small signal-only panel scripts**

Use these public signals:

```gdscript
# title_screen.gd
signal start_requested

# briefing_panel.gd
signal initial_hypothesis_submitted(hypothesis_id: String, confidence: int)

# hypothesis_panel.gd
signal hypothesis_revision_submitted(hypothesis_id: String, confidence: int, trigger_fact_ids: Array[String])
```

The title states that structured assessment actions are stored locally for Proof Replay, results support human review rather than an employment decision, and navigation speed is not scored. Panels never access `EventLogger`, `ScenarioState`, or scoring. They emit user intent and expose `configure(scenario_or_snapshot)` methods. Disable briefing confirmation until a hypothesis is selected. The hypothesis panel only lists facts from already-viewed artifacts.

HUD text always includes `WASD Move · E Interact · 1/2/3 Stations · H Hypothesis · Esc Close`. Expose `show_recording_warning(message)` and retain the warning until session completion.

- [ ] **Step 4: Run the UI suite**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Briefing UI import, UID, or test verification failed' }
```

Expected: keyboard focus, notice copy, option counts, and signal payloads pass.

- [ ] **Step 5: Commit the accessible opening and hypothesis flow**

```powershell
git add -- apps/incident-room/scenes/ui/title_screen.tscn apps/incident-room/scenes/ui/briefing_panel.tscn apps/incident-room/scenes/ui/hud.tscn apps/incident-room/scenes/ui/hypothesis_panel.tscn apps/incident-room/scripts/presentation/ui/title_screen.gd apps/incident-room/scripts/presentation/ui/title_screen.gd.uid apps/incident-room/scripts/presentation/ui/briefing_panel.gd apps/incident-room/scripts/presentation/ui/briefing_panel.gd.uid apps/incident-room/scripts/presentation/ui/hud.gd apps/incident-room/scripts/presentation/ui/hud.gd.uid apps/incident-room/scripts/presentation/ui/hypothesis_panel.gd apps/incident-room/scripts/presentation/ui/hypothesis_panel.gd.uid apps/incident-room/tests/test_briefing_hypothesis_ui.gd apps/incident-room/tests/test_briefing_hypothesis_ui.gd.uid
git commit --only -m "feat: add accessible briefing and hypothesis flow" -- apps/incident-room/scenes/ui/title_screen.tscn apps/incident-room/scenes/ui/briefing_panel.tscn apps/incident-room/scenes/ui/hud.tscn apps/incident-room/scenes/ui/hypothesis_panel.tscn apps/incident-room/scripts/presentation/ui/title_screen.gd apps/incident-room/scripts/presentation/ui/title_screen.gd.uid apps/incident-room/scripts/presentation/ui/briefing_panel.gd apps/incident-room/scripts/presentation/ui/briefing_panel.gd.uid apps/incident-room/scripts/presentation/ui/hud.gd apps/incident-room/scripts/presentation/ui/hud.gd.uid apps/incident-room/scripts/presentation/ui/hypothesis_panel.gd apps/incident-room/scripts/presentation/ui/hypothesis_panel.gd.uid apps/incident-room/tests/test_briefing_hypothesis_ui.gd apps/incident-room/tests/test_briefing_hypothesis_ui.gd.uid
```

### Task 10: Add the Observability and Scripted-AI Investigation Panels

**Files:**
- Create: `apps/incident-room/scenes/ui/observability_panel.tscn`
- Create: `apps/incident-room/scenes/ui/developer_panel.tscn`
- Create: `apps/incident-room/scripts/presentation/ui/observability_panel.gd`
- Create: `apps/incident-room/scripts/presentation/ui/developer_panel.gd`
- Create: `apps/incident-room/tests/test_station_panels.gd`

**Interfaces:**
- Consumes: the four scenario artifacts and scripted AI interaction.
- Produces: `evidence_selected(artifact_id, evidence_type)`, `ai_requested(prompt_id)`, and `ai_disposition_selected(response_id, option_id, verification_ids)`.

- [ ] **Step 1: Write failing evidence-tab and AI-disposition tests**

Assert metrics/log/trace panels contain exact seeded facts, code contains sequential awaits, opening a tab emits its artifact ID every time, Redis is not labeled a trap, and all AI choices are visible:

```gdscript
observability.configure(scenario)
observability.open_artifact("homepage_trace")
t.assert_equal(captured_artifact_id, "homepage_trace", "trace event intent")
t.assert_true(observability.visible_text().contains("waiting times accumulate"), "trace content")
t.assert_false(observability.visible_text().to_lower().contains("trap"), "Redis remains plausible")

developer.configure(scenario)
t.assert_true(developer.code_text.text.contains("await"), "sequential code is readable")
t.assert_equal(developer.disposition_ids(), ["accept_immediately", "verify_then_adapt", "reject_suggestion"], "AI dispositions")
```

- [ ] **Step 2: Run the station test to verify failure**

Expected: missing panels produce a non-zero exit.

- [ ] **Step 3: Implement panel rendering and intent signals**

The observability panel renders `metrics_overview`, `application_logs`, and `homepage_trace` as three keyboard-selectable tabs. Emit `evidence_selected` whenever a tab becomes active, including repeated openings.

The developer panel emits `evidence_selected("homepage_orchestrator", "source_code")` when opened. The Ask Assistant button displays the fixed prompt and response, then enables three disposition buttons. Label the response `Scripted offline assistant` and never show a network/model spinner.

- [ ] **Step 4: Run all suites and manually inspect text wrapping at 1280×720**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Station UI import, UID, or test verification failed' }
```

Expected: headless tests pass; no content requires horizontal scrolling at the target viewport.

- [ ] **Step 5: Commit the investigation surfaces**

```powershell
git add -- apps/incident-room/scenes/ui/observability_panel.tscn apps/incident-room/scenes/ui/developer_panel.tscn apps/incident-room/scripts/presentation/ui/observability_panel.gd apps/incident-room/scripts/presentation/ui/observability_panel.gd.uid apps/incident-room/scripts/presentation/ui/developer_panel.gd apps/incident-room/scripts/presentation/ui/developer_panel.gd.uid apps/incident-room/tests/test_station_panels.gd apps/incident-room/tests/test_station_panels.gd.uid
git commit --only -m "feat: add incident investigation stations" -- apps/incident-room/scenes/ui/observability_panel.tscn apps/incident-room/scenes/ui/developer_panel.tscn apps/incident-room/scripts/presentation/ui/observability_panel.gd apps/incident-room/scripts/presentation/ui/observability_panel.gd.uid apps/incident-room/scripts/presentation/ui/developer_panel.gd apps/incident-room/scripts/presentation/ui/developer_panel.gd.uid apps/incident-room/tests/test_station_panels.gd apps/incident-room/tests/test_station_panels.gd.uid
```

### Task 11: Complete Release Submission, Proof Replay UI, and Main Scene Wiring

**Files:**
- Create: `apps/incident-room/scenes/ui/release_panel.tscn`
- Create: `apps/incident-room/scenes/ui/replay_panel.tscn`
- Create: `apps/incident-room/scripts/presentation/ui/release_panel.gd`
- Create: `apps/incident-room/scripts/presentation/ui/replay_panel.gd`
- Create: `apps/incident-room/scenes/main/main.tscn`
- Create: `apps/incident-room/scripts/presentation/main.gd`
- Create: `apps/incident-room/tests/test_release_replay_ui.gd`
- Create: `apps/incident-room/tests/test_main_flow.gd`

**Interfaces:**
- Consumes: all facade commands/signals, room station requests, and UI intent signals.
- Produces: one fully playable primitive flow from title to Proof Replay, plus a clean new-session loop.

- [ ] **Step 1: Write failing release/replay and full-flow tests**

The release panel must emit this complete dictionary, allowing empty arrays/rationale for transparent warning paths:

```gdscript
{
    "root_cause_id": "sequential_independent_calls",
    "supporting_evidence_ids": ["cpu_not_saturated", "database_healthy", "downstream_calls_sequential_in_trace", "sequential_awaits_in_code", "calls_are_independent_in_code"],
    "remediation_id": "parallelize_confirmed_independent_calls",
    "expected_impact_id": "lower_p95_preserve_correctness",
    "risk_ids": ["partial_failure_behavior"],
    "assumption_ids": ["calls_are_independent"],
    "validation_test_ids": ["correctness_regression", "p95_latency"],
    "rollback_id": "restore_sequential_orchestration",
    "final_confidence": 90,
    "rationale": ""
}
```

The headless full-flow test instantiates `main.tscn`, calls `configure_runtime_dependencies(fake_store, clock, elapsed_clock, two_id_factory)` before adding it to the scene tree, calls public UI/controller methods, completes a correct path, and asserts `replay_panel` is visible, movement is disabled, replay rows exist, and session summary exists in the fake store. Trigger Replay's New Session action using the deterministic two-ID factory, then assert the second ID differs, its first/current event is `assessment_opened` at sequence one, replay and stale warnings are hidden, briefing is visible, optional panels are reset, and movement remains disabled until the new initial hypothesis. A separate path triggers at least one warning but still completes. For Escape, open each optional panel in turn and prove one press closes only that panel without pausing; with no optional panel open, prove Escape shows the pause overlay and sets `SceneTree.paused`, and a second Escape plus the Resume button each restore the unpaused state.

- [ ] **Step 2: Run the tests to verify failure**

Expected: missing release/replay/main files produce a non-zero exit.

- [ ] **Step 3: Implement release and replay panels**

Release controls include root cause, multi-select supporting fact citations, remediation, expected impact, multi-select risks and assumptions, two scripted test buttons, rollback, confidence, and optional rationale. Only viewed facts appear as normal supporting-evidence choices, while controller tests still cover a known-but-unviewed citation submitted programmatically. Test buttons require a remediation selection, emit `test_requested(test_id, subject_remediation_id)`, and display the clearly labelled scripted result returned by the session controller. Changing remediation clears displayed test results and requires executing/selecting the tests for the new remediation.

`ReplayPanel` exposes `signal new_session_requested()`. `render(view_model)` displays, in order: completion and persistence status, hypotheses, timeline rows, AI chain, verification, final submission, criterion cards with citations, technical errors, suggested questions, and notices, followed by a keyboard-focusable `New Session` button that emits the signal. Map internal criterion statuses to candidate copy exactly: `satisfied -> Met`, `not_satisfied -> Missed`, `triggered -> Warning`, `not_triggered -> Clear`, and `excluded -> Excluded`. Show no pass/fail label.

- [ ] **Step 4: Wire the main scene without domain leakage into panels**

`main.gd` is the sole router:

Expose `configure_runtime_dependencies(store: RefCounted, clock: Callable, elapsed_clock: Callable, session_id_factory: Callable) -> void`, callable only before the node enters the tree; tests use it to inject deterministic dependencies. On `_ready`, load `res://data/scenarios/homepage_latency_v1.json`, fill any dependency not injected with `SessionStore`, UTC/elapsed clocks, and the production session-ID factory, call `session_controller.configure(...)`, configure every panel from the same scenario, and then show the title screen. A loader failure shows a local fatal-error panel and does not start a partial assessment. Support the user argument `--smoke-test`: after successful scenario/panel configuration, call `get_tree().quit(0)`; if loading/configuration fails, quit `2`. This lets the packaged-build check prove the JSON entered the PCK without creating a session.

```gdscript
func _on_station_requested(station_id: String) -> void:
    match station_id:
        "observability_wall": observability_panel.open()
        "developer_desk": developer_panel.open()
        "release_console": release_panel.open(session_controller.get_snapshot())

func _on_replay_ready(view_model: Dictionary) -> void:
    player.set_enabled(false)
    replay_panel.render(view_model)
    replay_panel.show()

func _on_new_session_requested() -> void:
    _reset_presentation_for_new_session()
    var result := session_controller.begin_session()
    if not result.ok:
        _show_local_error(result.errors)
        return
    briefing_panel.open(session_controller.get_snapshot())

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("pause"):
        return
    if get_tree().paused:
        _set_paused(false)
    elif not _close_topmost_optional_panel():
        _set_paused(true)
    get_viewport().set_input_as_handled()
```

Connect `1`/`2`/`3` through the same station-request handler. Connect `H` to the hypothesis panel and Replay's `new_session_requested` to the handler above. Add a full-screen `PauseOverlay` inside `main.tscn` with `Paused`, controls reminder, and a keyboard-focusable Resume button. Let `main.gd` process always, put the world and ordinary interface roots in pausable process mode, and put only `PauseOverlay` in when-paused mode. `_set_paused(value)` shows/hides the overlay in the safe order and sets `get_tree().paused`; Resume calls `_set_paused(false)`. `_close_topmost_optional_panel` checks release, developer, observability, then hypothesis panels in visible-stack order and closes at most one. `_reset_presentation_for_new_session` first guarantees the tree is unpaused, then hides replay, pause, and every optional panel, clears panel selections/results plus HUD persistence warnings, restores the player spawn, disables movement, and resets station focus without retaining evidence from the prior session. Starting a session shows briefing; until the initial hypothesis succeeds, ignore station/quick-access requests and keep detailed evidence hidden. Submitting the initial hypothesis enables movement and investigation requests. Escape closes one active optional panel; when none is open it toggles the pause overlay.

- [ ] **Step 5: Run import, all tests, and a main-scene smoke test**

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot executable not found: $godot" }
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Vertical-slice import, UID, or test verification failed' }
& $godot --headless --path apps/incident-room --quit-after 3
if ($LASTEXITCODE -ne 0) { throw 'Godot vertical-slice smoke test failed' }
```

Expected: all commands exit `0`; the complete flow works with primitive visuals and no third-party runtime files.

- [ ] **Step 6: Commit the complete primitive vertical slice**

```powershell
git add -- apps/incident-room/scenes/main apps/incident-room/scenes/ui/release_panel.tscn apps/incident-room/scenes/ui/replay_panel.tscn apps/incident-room/scripts/presentation/main.gd apps/incident-room/scripts/presentation/main.gd.uid apps/incident-room/scripts/presentation/ui/release_panel.gd apps/incident-room/scripts/presentation/ui/release_panel.gd.uid apps/incident-room/scripts/presentation/ui/replay_panel.gd apps/incident-room/scripts/presentation/ui/replay_panel.gd.uid apps/incident-room/tests/test_release_replay_ui.gd apps/incident-room/tests/test_release_replay_ui.gd.uid apps/incident-room/tests/test_main_flow.gd apps/incident-room/tests/test_main_flow.gd.uid
git commit --only -m "feat: complete submission and proof replay flow" -- apps/incident-room/scenes/main apps/incident-room/scenes/ui/release_panel.tscn apps/incident-room/scenes/ui/replay_panel.tscn apps/incident-room/scripts/presentation/main.gd apps/incident-room/scripts/presentation/main.gd.uid apps/incident-room/scripts/presentation/ui/release_panel.gd apps/incident-room/scripts/presentation/ui/release_panel.gd.uid apps/incident-room/scripts/presentation/ui/replay_panel.gd apps/incident-room/scripts/presentation/ui/replay_panel.gd.uid apps/incident-room/tests/test_release_replay_ui.gd apps/incident-room/tests/test_release_replay_ui.gd.uid apps/incident-room/tests/test_main_flow.gd apps/incident-room/tests/test_main_flow.gd.uid
```

### Task 12: Fetch, Audit, Curate, and Apply the Free Diorama Assets

**Files:**
- Create: `apps/incident-room/scripts/development/fetch_assets.ps1`
- Create: `apps/incident-room/assets/third_party/manifest.json`
- Modify: `apps/incident-room/THIRD_PARTY_NOTICES.md`
- Create: selected source/runtime files and their Godot-generated `*.import` metadata under `apps/incident-room/assets/third_party/`
- Create: `apps/incident-room/scripts/presentation/asset_decorator.gd`
- Create: `apps/incident-room/tests/test_asset_manifest.gd`
- Modify: `apps/incident-room/scripts/presentation/room_builder.gd`
- Modify: `apps/incident-room/scripts/presentation/player_controller.gd`
- Modify: `apps/incident-room/scripts/presentation/ui/hud.gd`

**Interfaces:**
- Consumes: the fully working primitive room and original source URLs.
- Produces: a curated CC0 asset set, provenance manifest, optional decorated room, chibi visual trial, input glyphs, and three interface sounds. Primitive fallbacks remain functional.

- [ ] **Step 1: Write the failing manifest and loadability test**

Enumerate every source/runtime file beneath `assets/third_party` except `manifest.json` and Godot-generated `*.import` sidecars. Assert each remaining relative path occurs exactly once in the manifest with creator, source URL, retrieval date, license, archive/revision identifier, and modifications. Assert every listed `.gltf`, `.glb`, `.png`, and `.ogg` loads through Godot. Never list generated `.import` files as third-party provenance, but do retain and commit them after successful import so Godot importer settings are reproducible. In the same suite, assert `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_COPYRIGHT.txt` still have the Task 1 SHA-256 values and that `THIRD_PARTY_NOTICES.md` still contains the Godot Engine section.

```gdscript
for entry in manifest.files:
    t.assert_true(FileAccess.file_exists("res://assets/third_party/" + entry.path), "listed file exists: %s" % entry.path)
    t.assert_equal(entry.license, "CC0-1.0", "approved license")
    t.assert_true(not entry.source_url.is_empty(), "source recorded")
t.assert_equal(sorted_disk_files, sorted_manifest_files, "no unlisted third-party runtime file")
```

- [ ] **Step 2: Run the asset test to verify it fails**

Expected: manifest/assets are absent.

- [ ] **Step 3: Implement the pinned acquisition script**

The PowerShell script begins with `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`, downloads into an isolated temporary directory, rejects unexpected executable/script extensions, and copies only these pinned files:

```powershell
$FurnitureRepo = 'https://github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0.git'
$FurnitureRevision = '96d5930a8dbdb363409bbc2d3341718b00e17c9c'
$SpaceRepo = 'https://github.com/KayKit-Game-Assets/KayKit-Space-Base-Bits-1.0.git'
$SpaceRevision = '6dfbcac9927d06283752c4defd4882cfe0d29666'
$KenneyInputUrl = 'https://kenney.nl/media/pages/assets/input-prompts/8de120163f-1783763952/kenney_input-prompts_1.5.zip'
$KenneyInputSha256 = 'AC2FCF599080B0F3BA2D174C9474DB6DF1A0E96FF0662580E2DA79A122AB78A1'
$KenneyAudioUrl = 'https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip'
$KenneyAudioSha256 = 'F2193D072726D6758A5F7871B2DCC54DCCE0D5C35C6F0A62F92549B327C81232'
$ChibiUrl = 'https://store.godotengine.org/asset/styloo/chibi/download/1373/'
$ChibiSha256 = 'AD929E2D15D172967453DF5131B59247CC54EBE97BBF0863CECF30761C380BE8'

$FurnitureModelNames = @(
  'book_set','cabinet_medium','cactus_medium_A','chair_A',
  'couch','lamp_standing','shelf_B_large','table_medium_long'
)
$SpaceModelNames = @('cargo_A','containers_A','lights','structure_low')
$PromptFiles = @(
  'keyboard_w.png','keyboard_a.png','keyboard_s.png','keyboard_d.png','keyboard_e.png',
  'keyboard_h.png','keyboard_1.png','keyboard_2.png','keyboard_3.png','keyboard_escape.png'
)
$AudioFiles = @('open_001.ogg','select_001.ogg','confirmation_001.ogg')
$ChibiFiles = @('studentpr.glb','Read Me .txt')
```

Clone the two KayKit GitHub repositories from the exact URLs above, detach-checkout the pinned revisions, and verify `git rev-parse HEAD` before copying. Furniture sources come from `addons/kaykit_furniture_bits/Assets/gltf/`; Space sources come from `addons/kaykit_space_base_bits/Assets/gltf/`. For each model name, copy both `<name>.gltf` and its required `<name>.bin`, plus that directory's `furniturebits_texture.png` or `spacebits_texture.png` and the pack `LICENSE.txt`, preserving same-directory relative references. Download and hash-check the Kenney and Chibi archives before extraction. Copy prompts only from `Keyboard & Mouse/Default/`, audio only from `Audio/`, and the character from `glb/studentpr.glb`. Reject `.exe`, `.dll`, `.gdextension`, `.bat`, and unexpected `.ps1` files. Preserve both Kenney root `License.txt` files. Rename the Chibi `Read Me .txt` to `README-source.txt` and record the Godot Store CC0 listing because its archive lacks a license file. If the script cleans its unique staging directory, resolve both the staging root and deletion target and assert the target remains beneath that root before any recursive removal.

Append one provenance section per retained asset pack to `THIRD_PARTY_NOTICES.md`; never replace or edit away its Task 1 Godot Engine section or the two engine license files.

- [ ] **Step 4: Run acquisition, import, and manifest tests**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/fetch_assets.ps1
if ($LASTEXITCODE -ne 0) { throw 'Asset acquisition failed' }
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
if ($LASTEXITCODE -ne 0) { throw 'Asset import, metadata, UID, or test verification failed' }
```

Expected: hashes/revisions match, no executable payload is copied, all retained resources import, and the inventory test passes. If `studentpr.glb` alone fails loadability, remove the Chibi runtime files and manifest/notices entries, rerun import/tests, and continue with the primitive character; do not weaken the manifest test.

- [ ] **Step 5: Decorate the room without making assets mandatory**

`AssetDecorator.decorate(room_root)` loads selected `PackedScene` resources only after checking `ResourceLoader.exists(path)`. Place tables/chairs/cabinets/plants in the office area and use cargo/containers/lights only as diagnostics accents. Screen content, monitors, observability wall, release controls, room shell, and floor markers remain first-party primitives.

Time-box `studentpr.glb` integration to 30 minutes. Find its `AnimationPlayer`, map case-insensitive names containing `idle`, `walk`, and `run`, and swap animations from player velocity. If import/material/animation/collision is not clean by the timebox, remove Chibi runtime files from the manifest and repository and retain the primitive chibi fallback.

HUD uses the ten selected keyboard glyphs; UI uses open, select, and confirmation sounds with text alternatives and a mute-safe absence fallback.

- [ ] **Step 6: Complete the provenance notices**

`THIRD_PARTY_NOTICES.md` records creator, original page, pinned revision or archive hash, retrieval date `2026-07-15`, CC0-1.0, exact included files, and modifications for KayKit Furniture Bits, KayKit Space Base Bits, Kenney Input Prompts 1.5, Kenney Interface Sounds 1.0, and Chibi Characters v1.0 when retained.

- [ ] **Step 7: Commit the curated asset set and polish**

```powershell
git add -- apps/incident-room/assets/third_party apps/incident-room/THIRD_PARTY_NOTICES.md apps/incident-room/scripts/development/fetch_assets.ps1 apps/incident-room/scripts/presentation/asset_decorator.gd apps/incident-room/scripts/presentation/asset_decorator.gd.uid apps/incident-room/scripts/presentation/room_builder.gd apps/incident-room/scripts/presentation/room_builder.gd.uid apps/incident-room/scripts/presentation/player_controller.gd apps/incident-room/scripts/presentation/player_controller.gd.uid apps/incident-room/scripts/presentation/ui/hud.gd apps/incident-room/scripts/presentation/ui/hud.gd.uid apps/incident-room/tests/test_asset_manifest.gd apps/incident-room/tests/test_asset_manifest.gd.uid
git commit --only -m "feat: apply licensed diorama assets and polish" -- apps/incident-room/assets/third_party apps/incident-room/THIRD_PARTY_NOTICES.md apps/incident-room/scripts/development/fetch_assets.ps1 apps/incident-room/scripts/presentation/asset_decorator.gd apps/incident-room/scripts/presentation/asset_decorator.gd.uid apps/incident-room/scripts/presentation/room_builder.gd apps/incident-room/scripts/presentation/room_builder.gd.uid apps/incident-room/scripts/presentation/player_controller.gd apps/incident-room/scripts/presentation/player_controller.gd.uid apps/incident-room/scripts/presentation/ui/hud.gd apps/incident-room/scripts/presentation/ui/hud.gd.uid apps/incident-room/tests/test_asset_manifest.gd apps/incident-room/tests/test_asset_manifest.gd.uid
```

### Task 13: Verify, Export, Document, and Smoke-Test the Windows MVP

**Files:**
- Modify: `apps/incident-room/README.md`
- Modify: `README.md`
- Verify: `apps/incident-room/export_presets.cfg`
- Verify: all project files and packaged build

**Interfaces:**
- Consumes: completed project, test suite, export templates, and manual playthrough matrix.
- Produces: verified Windows executable under ignored `dist/windows/` plus concise repository documentation for the optional experiment.

- [ ] **Step 1: Run the complete automated verification from a clean Godot import**

```powershell
$ErrorActionPreference = 'Stop'
$toolRoot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1'
$godot = Join-Path $toolRoot 'Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot 4.7.1 console executable not found at $godot" }
$project = (Resolve-Path -LiteralPath (Join-Path $PWD 'prototypes\godot-incident-room')).Path
$projectPrefix = $project.TrimEnd('\') + '\'
$cache = [IO.Path]::GetFullPath((Join-Path $project '.godot'))
if (-not $cache.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe Godot cache path: $cache" }
if (Test-Path -LiteralPath $cache) {
    $cacheItem = Get-Item -LiteralPath $cache -Force
    if (($cacheItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing recursive removal of reparse point: $cache" }
    Remove-Item -LiteralPath $cache -Recurse -Force -ErrorAction Stop
    if (Test-Path -LiteralPath $cache) { throw "Godot cache still exists after removal: $cache" }
}
& $godot --headless --path $project --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $godot --headless --path $project --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { throw 'Godot tests failed' }
& $godot --headless --path $project --quit-after 3
if ($LASTEXITCODE -ne 0) { throw 'Main scene smoke test failed' }
```

Expected: all three commands exit `0`, with no parser, missing-resource, orphan-node, or leaked-object errors.

- [ ] **Step 2: Run the manual playthrough matrix before export**

Complete and record results in the project README for:

1. Correct path in three to five minutes using movement and `E`.
2. Correct path using only `1`/`2`/`3`, proving movement is optional.
3. Plausible incorrect CPU-scaling/unverified-AI path, proving warnings and replay contrast.
4. Repeated evidence views, proving replay duplication but idempotent scoring.
5. Forced persistence failure, proving warning, in-memory completion, and replay status.
6. Keyboard focus and Escape behavior for every panel.
7. New session after completion, proving a clean ID and sequence restart.
8. Camera framing at 1280×720 and one wider window, proving player/stations remain visible.

- [ ] **Step 3: Export the Windows x86_64 build**

```powershell
$ErrorActionPreference = 'Stop'
$godot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot executable not found: $godot" }
$project = (Resolve-Path -LiteralPath (Join-Path $PWD 'prototypes\godot-incident-room')).Path
$dist = Join-Path $project 'dist\windows'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$exe = Join-Path $dist 'VibeProofIncidentRoom.exe'
if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
& $godot --headless --path $project --export-release 'Windows Desktop' $exe
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or (Get-Item -LiteralPath $exe).Length -le 0) { throw 'Windows export is missing or empty' }
$godotLicenseSource = Join-Path $project 'licenses\GODOT_LICENSE.txt'
$godotCopyrightSource = Join-Path $project 'licenses\GODOT_COPYRIGHT.txt'
if ((Get-FileHash $godotLicenseSource -Algorithm SHA256).Hash -ne 'B0435E3B3E4E55238F05F4B306F30524A1B2E20147810D436EAA554FA6855C80') { throw 'Godot distribution license hash mismatch' }
if ((Get-FileHash $godotCopyrightSource -Algorithm SHA256).Hash -ne 'CB1980C88089573BCACD7221D777C689BB8BBD778799F24C27FCA0FE5F774D6D') { throw 'Godot distribution copyright hash mismatch' }
$noticeSources = @(
    (Join-Path $project 'THIRD_PARTY_NOTICES.md'),
    $godotLicenseSource,
    $godotCopyrightSource
)
foreach ($source in $noticeSources) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Get-Item -LiteralPath $source).Length -le 0) { throw "Required distribution notice is missing or empty: $source" }
    Copy-Item -LiteralPath $source -Destination $dist -Force -ErrorAction Stop
    $copied = Join-Path $dist (Split-Path -Leaf $source)
    if (-not (Test-Path -LiteralPath $copied -PathType Leaf) -or (Get-Item -LiteralPath $copied).Length -le 0) { throw "Distribution notice copy failed: $copied" }
}
$smoke = Start-Process -FilePath $exe -ArgumentList @('--headless','--','--smoke-test') -PassThru -WindowStyle Hidden -ErrorAction Stop
if (-not $smoke.WaitForExit(15000)) {
    Stop-Process -Id $smoke.Id -Force -ErrorAction Stop
    if (-not $smoke.WaitForExit(5000)) { throw 'Timed-out packaged scenario smoke process could not be terminated' }
    throw 'Packaged scenario smoke test timed out after 15 seconds'
}
if ($smoke.ExitCode -ne 0) { throw "Packaged scenario smoke test failed with code $($smoke.ExitCode)" }
Get-ChildItem -LiteralPath $dist | Select-Object Name,Length,LastWriteTime
```

Expected: export exits `0`; `VibeProofIncidentRoom.exe`, `THIRD_PARTY_NOTICES.md`, `GODOT_LICENSE.txt`, and `GODOT_COPYRIGHT.txt` all exist with non-zero size.

- [ ] **Step 4: Smoke-test the packaged executable**

Launch it hidden for five seconds to confirm startup, then perform one visible full playthrough:

```powershell
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PWD 'prototypes\godot-incident-room')).Path
$dist = Join-Path $project 'dist\windows'
$null = New-Item -ItemType Directory -Force -Path $dist
$exe = Join-Path $dist 'VibeProofIncidentRoom.exe'
$process = Start-Process -FilePath $exe -PassThru -WindowStyle Hidden -ErrorAction Stop
if ($process.WaitForExit(5000)) { throw "Packaged build exited unexpectedly with code $($process.ExitCode)" }
Stop-Process -Id $process.Id -Force -ErrorAction Stop
if (-not $process.WaitForExit(5000)) { throw 'Packaged build could not be terminated after smoke test' }
```

Expected: no immediate crash. The visible playthrough must reach Proof Replay and create `events.jsonl` plus `summary.json` under the Godot user-data directory.

- [ ] **Step 5: Finish documentation without changing the canonical product boundary**

The project README must include exact install/run/export commands, controls, event-log location, resource/license summary, scripted-AI notice, known limitations, manual matrix result, the statement that navigation is unscored, and an instruction to distribute all three notice/license files beside the executable.

Add this short root README section after `## MVP`:

```markdown
### Optional Incident Room prototype

The [Godot Incident Room](apps/incident-room/README.md) is an optional presentation experiment for the same controlled scenario and evidence model. It does not replace the baseline web workspace, and navigation performance is not scored.
```

- [ ] **Step 6: Re-run final verification, stage explicit handoff files, and inspect the exact staged diff**

Run import, tests, main-scene smoke, and export again. Then run:

```powershell
$ErrorActionPreference = 'Stop'
$godot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot executable not found: $godot" }
$project = (Resolve-Path -LiteralPath (Join-Path $PWD 'prototypes\godot-incident-room')).Path
& $godot --headless --path $project --import
if ($LASTEXITCODE -ne 0) { throw 'Final Godot import failed' }
& $godot --headless --path $project --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { throw 'Final Godot tests failed' }
& $godot --headless --path $project --quit-after 3
if ($LASTEXITCODE -ne 0) { throw 'Final main scene smoke test failed' }
$dist = Join-Path $project 'dist\windows'
$null = New-Item -ItemType Directory -Force -Path $dist
$exe = Join-Path $dist 'VibeProofIncidentRoom.exe'
if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
& $godot --headless --path $project --export-release 'Windows Desktop' $exe
if ($LASTEXITCODE -ne 0) { throw 'Final Windows export failed' }
if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or (Get-Item -LiteralPath $exe).Length -le 0) { throw 'Final Windows export is missing or empty' }
$godotLicenseSource = Join-Path $project 'licenses\GODOT_LICENSE.txt'
$godotCopyrightSource = Join-Path $project 'licenses\GODOT_COPYRIGHT.txt'
if ((Get-FileHash $godotLicenseSource -Algorithm SHA256).Hash -ne 'B0435E3B3E4E55238F05F4B306F30524A1B2E20147810D436EAA554FA6855C80') { throw 'Final Godot distribution license hash mismatch' }
if ((Get-FileHash $godotCopyrightSource -Algorithm SHA256).Hash -ne 'CB1980C88089573BCACD7221D777C689BB8BBD778799F24C27FCA0FE5F774D6D') { throw 'Final Godot distribution copyright hash mismatch' }
$noticeSources = @(
    (Join-Path $project 'THIRD_PARTY_NOTICES.md'),
    $godotLicenseSource,
    $godotCopyrightSource
)
foreach ($source in $noticeSources) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Get-Item -LiteralPath $source).Length -le 0) { throw "Required final distribution notice is missing or empty: $source" }
    Copy-Item -LiteralPath $source -Destination $dist -Force -ErrorAction Stop
    $copied = Join-Path $dist (Split-Path -Leaf $source)
    if (-not (Test-Path -LiteralPath $copied -PathType Leaf) -or (Get-Item -LiteralPath $copied).Length -le 0) { throw "Final distribution notice copy failed: $copied" }
}
$smoke = Start-Process -FilePath $exe -ArgumentList @('--headless','--','--smoke-test') -PassThru -WindowStyle Hidden -ErrorAction Stop
if (-not $smoke.WaitForExit(15000)) {
    Stop-Process -Id $smoke.Id -Force -ErrorAction Stop
    if (-not $smoke.WaitForExit(5000)) { throw 'Timed-out final packaged smoke process could not be terminated' }
    throw 'Final packaged scenario smoke test timed out after 15 seconds'
}
if ($smoke.ExitCode -ne 0) { throw "Final packaged scenario smoke test failed with code $($smoke.ExitCode)" }
git diff --check -- README.md apps/incident-room
if ($LASTEXITCODE -ne 0) { throw 'Working-tree diff check failed' }
$alreadyStaged = @(git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect existing staged changes' }
if ($alreadyStaged.Count -gt 0) { throw "Unexpected pre-existing staged changes: $($alreadyStaged -join ', ')" }
git add -- README.md apps/incident-room/README.md apps/incident-room/export_presets.cfg
if ($LASTEXITCODE -ne 0) { throw 'Explicit staging failed' }
git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Cached diff check failed' }
git diff --cached --stat
if ($LASTEXITCODE -ne 0) { throw 'Cached diff stat failed' }
git diff --cached -- README.md apps/incident-room/README.md apps/incident-room/export_presets.cfg
if ($LASTEXITCODE -ne 0) { throw 'Cached diff inspection failed' }
git status --short
```

Expected: the cached diff contains only the three intended handoff files; session logging and `.superpowers/` remain untouched and unstaged.

- [ ] **Step 7: Commit the verified Windows prototype handoff**

```powershell
git commit --only -m "build: verify Windows incident room prototype" -- README.md apps/incident-room/README.md apps/incident-room/export_presets.cfg
```

## Final Acceptance Evidence

Before claiming completion, preserve command output demonstrating:

- Godot version begins `4.7.1.stable`.
- Clean import exits `0`.
- Every headless suite passes.
- Main-scene smoke exits `0`.
- The correct and incorrect manual paths both reach Proof Replay.
- Movement-free quick access exposes every evidence surface.
- A persistence failure still produces an in-memory replay with a visible warning.
- Every third-party runtime file is covered by the manifest and notices.
- Windows export exits `0`; its three non-empty engine/asset notice files sit beside the executable; and the packaged executable survives startup plus a full visible playthrough.

Do not attempt the optional web export until every item above is satisfied.
