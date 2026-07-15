# VibeProof Godot-First Candidate Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete offline Godot candidate journey for the Homepage Latency Spike scenario, persist structured local events, and finish with an explicitly unscored session summary.

**Architecture:** Extend the existing Godot 4.7.1 scaffold with engine-light event, persistence, session-state, and summary units. Presentation scenes emit intent to one coordinator and never score candidates. The JSONL event envelope is the future backend boundary; scoring configuration remains validated scenario data but is not consumed by this runtime.

**Tech Stack:** Godot 4.7.1 Standard, GDScript, Compatibility renderer, JSON scenario data, JSONL session logs, first-party headless tests, and PowerShell verification.

## Global Constraints

- Follow the approved [Godot-first candidate-flow design](../specs/2026-07-15-vibeproof-godot-first-candidate-flow-design.md).
- Keep the project independently loadable under `apps/incident-room/`.
- Run without a backend, account, network request, live model, or arbitrary code execution.
- Do not calculate or display points, criteria, pass/fail status, rank, capability labels, or hiring recommendations.
- Do not use movement speed, route, camera skill, station order, or interaction count as assessment evidence.
- Use stable scenario IDs in events; display text remains presentation data.
- Continue after disk-write failure using the in-memory event list and a visible warning.
- Preserve human-review, prototype-limitation, navigation-unscored, engine-license, and third-party notices.
- Commit every Godot-generated `*.gd.uid` beside its script.
- Run every production behavior through a witnessed red-green test cycle.

## Planned structure

```text
apps/incident-room/
|-- scenes/{main,room,player,stations,ui}/
|-- scripts/
|   |-- domain/{event_schema,candidate_session,unscored_summary_builder}.gd
|   |-- persistence/event_logger.gd
|   `-- presentation/{main,player_controller,station_trigger,title_screen,briefing_panel,investigation_panel,hypothesis_panel,release_panel,unscored_summary}.gd
`-- tests/{test_event_schema,test_event_logger,test_candidate_session,test_unscored_summary_builder,test_panel_contracts,test_room_contracts,test_main_flow,test_acceptance_paths}.gd
```

---

### Task 1: Define the unscored event contract

**Files:**
- Create: `apps/incident-room/scripts/domain/event_schema.gd`
- Create: `apps/incident-room/tests/test_event_schema.gd`

**Interfaces:**
- Consumes: stable scenario IDs.
- Produces: `EventSchema.build(...) -> Dictionary` and `EventSchema.validate(...) -> PackedStringArray`.

- [ ] **Step 1: Write the failing event test**

Create a suite with this behavior:

```gdscript
func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var event := EventSchema.build(
        "session-1", 1, "assessment_opened", "2026-07-15T13:00:00Z",
        "homepage_latency", "1.0.0", {"notice_confirmed": true}
    )
    t.assert_has_keys(event, ["schema_version", "session_id", "sequence", "event_type", "recorded_at_utc", "scenario_id", "scenario_version", "payload"], "event envelope")
    t.assert_equal(EventSchema.validate(event), PackedStringArray(), "valid event")
    event.payload.score = 10
    t.assert_true(EventSchema.validate(event).has("Scoring field is forbidden: score"), "score rejected")
    return t.failures
```

- [ ] **Step 2: Run RED**

Run the combined verification script. Expected: failure because `EventSchema` is missing.

- [ ] **Step 3: Implement the schema**

Create `class_name EventSchema` with schema version `1.0.0`, the eight envelope keys above, and recursive rejection of `score`, `points`, `criteria`, `pass`, `rank`, `capability`, and `recommendation`.

Freeze this complete event-name set: `assessment_opened`, `hypothesis_recorded`, `evidence_viewed`, `ai_prompt_submitted`, `ai_response_received`, `ai_suggestion_dispositioned`, `hypothesis_revised`, `test_executed`, `decision_recorded`, and `final_submission`.

```gdscript
static func build(session_id: String, sequence: int, event_type: String,
        recorded_at_utc: String, scenario_id: String, scenario_version: String,
        payload: Dictionary) -> Dictionary

static func validate(event: Dictionary) -> PackedStringArray
```

Validation rejects blank IDs, sequence below `1`, unknown event types, non-dictionary payloads, and forbidden nested keys.

- [ ] **Step 4: Run GREEN**

Expected: successful import and `TESTS PASSED: 2 suites`.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/scripts/domain/event_schema.gd* apps/incident-room/tests/test_event_schema.gd*
git commit -m "feat: define unscored assessment events"
```

---

### Task 2: Append events with an in-memory fallback

**Files:**
- Create: `apps/incident-room/scripts/persistence/event_logger.gd`
- Create: `apps/incident-room/tests/test_event_logger.gd`

**Interfaces:**
- Consumes: `EventSchema`.
- Produces: ordered in-memory events and `events.jsonl`.

- [ ] **Step 1: Write failing persistence tests**

Create a logger with a unique `user://test-vibeproof/<session>` directory. Append two events, parse both JSONL lines, and assert sequences `1` and `2`. Inject a writer callable returning `ERR_CANT_CREATE`; assert the event remains in memory and a warning is set.

```gdscript
EventLogger.new("session-1", "homepage_latency", "1.0.0", "user://test-vibeproof", Callable())
```

- [ ] **Step 2: Run RED**

Expected: missing `EventLogger`.

- [ ] **Step 3: Implement the logger**

Use system UTC timestamps, validate before append, retain a deep copy in memory, and write compact JSON plus newline. Expose exactly:

```gdscript
func append(event_type: String, payload: Dictionary) -> Dictionary
func events() -> Array[Dictionary]
func has_persistence_warning() -> bool
func persistence_warning() -> String
func session_directory() -> String
```

Invalid events return `ok: false` without sequence mutation. Write failure returns `ok: true` and `saved: false` while retaining the event.

- [ ] **Step 4: Run GREEN and parse JSONL**

Expected: all lines parse and sequences are monotonic.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/scripts/persistence/event_logger.gd* apps/incident-room/tests/test_event_logger.gd*
git commit -m "feat: persist candidate events locally"
```

---

### Task 3: Model the complete candidate session without scoring

**Files:**
- Create: `apps/incident-room/scripts/domain/candidate_session.gd`
- Create: `apps/incident-room/tests/test_candidate_session.gd`

**Interfaces:**
- Consumes: validated scenario and `EventLogger`.
- Produces: intent API and immutable presentation snapshot.

- [ ] **Step 1: Write a failing full-flow test**

Exercise this exact sequence:

```gdscript
session.open_assessment(true)
session.record_initial_hypothesis("redis_degradation", 40)
session.view_evidence("metrics_overview")
session.view_evidence("homepage_trace")
session.view_evidence("homepage_orchestrator")
session.record_ai_disposition("verify_then_adapt")
session.revise_hypothesis("sequential_independent_calls", 85, ["downstream_calls_sequential_in_trace"])
session.record_verification("correctness_regression", "parallelize_confirmed_independent_calls")
session.record_verification("p95_latency", "parallelize_confirmed_independent_calls")
session.submit_final({"root_cause_id": "sequential_independent_calls", "evidence_ids": ["homepage_trace", "homepage_orchestrator"], "remediation_id": "parallelize_confirmed_independent_calls", "risk_ids": ["partial_failure_behavior"], "assumption_ids": ["calls_are_independent"], "validation_test_ids": ["correctness_regression", "p95_latency"], "rollback_id": "restore_sequential_orchestration", "final_confidence": 90, "rationale": "Trace and source show independent sequential waits."})
```

Assert completion and event order. Add negative cases for evidence before initial hypothesis, unknown IDs, confidence outside `0..100`, and missing required submission fields.

- [ ] **Step 2: Run RED**

Expected: missing `CandidateSession`.

- [ ] **Step 3: Implement intent handling**

Create `class_name CandidateSession extends RefCounted` with these methods:

```gdscript
func open_assessment(notice_confirmed: bool) -> Dictionary
func record_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary
func view_evidence(artifact_id: String) -> Dictionary
func record_ai_disposition(option_id: String) -> Dictionary
func revise_hypothesis(hypothesis_id: String, confidence: int, trigger_fact_ids: Array) -> Dictionary
func record_verification(test_id: String, remediation_id: String) -> Dictionary
func submit_final(submission: Dictionary) -> Dictionary
func snapshot() -> Dictionary
func ordered_events() -> Array[Dictionary]
```

Validate all IDs against scenario collections. Emit the three scripted-AI events together. Preserve repeated evidence views. Never read `scenario.scoring`.

- [ ] **Step 4: Run GREEN**

Expected: all candidate-flow and negative fixtures pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/scripts/domain/candidate_session.gd* apps/incident-room/tests/test_candidate_session.gd*
git commit -m "feat: model the unscored candidate journey"
```

---

### Task 4: Build the unscored summary

**Files:**
- Create: `apps/incident-room/scripts/domain/unscored_summary_builder.gd`
- Create: `apps/incident-room/tests/test_unscored_summary_builder.gd`

**Interfaces:**
- Consumes: scenario, snapshot, ordered events, and persistence status.
- Produces: `UnscoredSummaryBuilder.build(...) -> Dictionary`.

- [ ] **Step 1: Write the failing summary test**

Assert keys `label`, `session_id`, `scenario_id`, `scenario_version`, `completed`, `saved_to_disk`, `persistence_warning`, `initial_hypothesis`, `final_hypothesis`, `evidence_timeline`, `ai_disposition`, `verification_actions`, `final_submission`, and `notices`. Assert `label == "Unscored prototype summary"` and recursively reject every scoring key from Task 1.

- [ ] **Step 2: Run RED**

Expected: missing builder.

- [ ] **Step 3: Implement the builder**

```gdscript
static func build(scenario: Dictionary, snapshot: Dictionary,
        events: Array[Dictionary], saved_to_disk: bool,
        persistence_warning: String) -> Dictionary
```

Map IDs to scenario labels, preserve repeated evidence chronology, and copy final choices without evaluation. Perform no file access.

- [ ] **Step 4: Run GREEN**

Expected: correct, incorrect, and persistence-warning summaries pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/scripts/domain/unscored_summary_builder.gd* apps/incident-room/tests/test_unscored_summary_builder.gd*
git commit -m "feat: build unscored session summaries"
```

---

### Task 5: Build candidate-flow panels

**Files:**
- Create: `scenes/ui/title_screen.tscn`, `briefing_panel.tscn`, `investigation_panel.tscn`, `hypothesis_panel.tscn`, `release_panel.tscn`, `unscored_summary.tscn`.
- Create: matching scripts under `scripts/presentation/`.
- Create: `tests/test_panel_contracts.gd`.

**Interfaces:**
- Consumes: scenario dictionaries and session snapshots.
- Produces: intent signals only.

- [ ] **Step 1: Write failing scene-contract tests**

Instantiate every scene and assert:

```text
TitleScreen: start_requested; configure(notices)
BriefingPanel: hypothesis_submitted(hypothesis_id, confidence); configure(scenario)
InvestigationPanel: artifact_viewed(artifact_id), ai_disposition_selected(option_id); configure(station_id, scenario, snapshot)
HypothesisPanel: revision_submitted(hypothesis_id, confidence, fact_ids); configure(scenario, snapshot)
ReleasePanel: verification_requested(test_id, remediation_id), final_submission_requested(submission); configure(scenario, snapshot)
UnscoredSummary: restart_requested; configure(summary)
```

Assert roots are `Control`, only title begins visible, and interactive controls accept keyboard focus.

- [ ] **Step 2: Run RED**

Expected: missing scenes.

- [ ] **Step 3: Implement primitive panels**

Use built-in containers, labels, tabs, option buttons, sliders, item lists, and buttons. Populate from scenario data. Disable briefing confirmation until hypothesis and confidence are selected. Disable submission until root cause, remediation, one validation, rollback, and confidence are present. Emit stable IDs. Display `Unscored prototype summary` and both notices exactly.

- [ ] **Step 4: Run GREEN and keyboard checks**

Run automated verification, then confirm `Tab`, arrows, `Enter`, and `Esc` work without a mouse.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/scenes/ui apps/incident-room/scripts/presentation apps/incident-room/tests/test_panel_contracts.gd*
git commit -m "feat: add the Godot candidate flow panels"
```

---

### Task 6: Build the room, player, camera, and stations

**Files:**
- Create: `scenes/room/incident_room.tscn`, `scenes/player/player.tscn`, `scenes/stations/station_trigger.tscn`.
- Create: `scripts/presentation/player_controller.gd`, `station_trigger.gd`.
- Create: `tests/test_room_contracts.gd`.
- Modify: `project.godot` input actions.

**Interfaces:**
- Consumes: movement, interact, quick-access, hypothesis, and cancel actions.
- Produces: `interaction_requested(station_id)` and `nearest_station_changed(station_id)`.

- [ ] **Step 1: Write failing room tests**

Assert one fixed orthographic camera, floor collision, exactly three stable station IDs, and a `CharacterBody3D` player.

- [ ] **Step 2: Run RED**

Expected: missing room scenes.

- [ ] **Step 3: Implement the greybox**

Build a 16-by-10-meter cutaway room from primitives. Place observability rear-left, developer desk rear-right, and release console front-right with a clear central path. Add camera-aligned movement, player rotation, collision, `E` proximity interaction, and equivalent `1`/`2`/`3` access. Movement code must not call the session or logger.

- [ ] **Step 4: Run GREEN and movement checks**

Confirm player visibility, room boundaries, and access through both input paths.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/project.godot apps/incident-room/scenes/room apps/incident-room/scenes/player apps/incident-room/scenes/stations apps/incident-room/scripts/presentation/player_controller.gd* apps/incident-room/scripts/presentation/station_trigger.gd* apps/incident-room/tests/test_room_contracts.gd*
git commit -m "feat: build the playable Incident Room greybox"
```

---

### Task 7: Wire the complete candidate flow

**Files:**
- Create: `apps/incident-room/scripts/presentation/main.gd`
- Modify: `apps/incident-room/scenes/main/main.tscn`
- Create: `apps/incident-room/tests/test_main_flow.gd`

**Interfaces:**
- Consumes: Tasks 1-6.
- Produces: one coordinator and `summary.json` at completion.

- [ ] **Step 1: Write failing coordinator tests**

Inject a scenario and memory logger, drive the flow, and assert phases `title -> briefing -> room -> summary`. Assert rejected intent does not change phase and restart creates a different session ID with empty state.

- [ ] **Step 2: Run RED**

Expected: main coordinator missing.

- [ ] **Step 3: Implement coordination**

Load the scenario, create logger/session, connect signals, pause player input under modals, and route all accepted intent through `CandidateSession`. Expose:

```gdscript
func begin_session() -> Dictionary
func submit_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary
func open_station(station_id: String) -> Dictionary
func open_hypothesis_panel() -> Dictionary
func submit_revision(hypothesis_id: String, confidence: int, fact_ids: Array) -> Dictionary
func submit_final(submission: Dictionary) -> Dictionary
func restart_session() -> Dictionary
func current_phase() -> String
```

After accepted submission, build and display the summary and write `summary.json` beside the event file. Summary-write failure remains visible but non-blocking.

- [ ] **Step 4: Run GREEN**

Expected: all suites pass and `main.tscn` loads headlessly.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/scenes/main/main.tscn apps/incident-room/scripts/presentation/main.gd* apps/incident-room/tests/test_main_flow.gd*
git commit -m "feat: connect the complete Godot candidate flow"
```

---

### Task 8: Verify acceptance paths and documentation

**Files:**
- Create: `apps/incident-room/tests/test_acceptance_paths.gd`
- Modify: `apps/incident-room/README.md`

**Interfaces:**
- Consumes: integrated flow.
- Produces: correct, incorrect, fallback, and restart evidence.

- [ ] **Step 1: Write failing acceptance tests**

Create an evidence-based sequential-calls path, unsupported CPU path, persistence-failure path, and restart path. Assert each reaches the unscored summary and preserves its selections. Require the README sentence `The current prototype is intentionally unscored.` so RED is witnessed before documentation changes.

- [ ] **Step 2: Run RED**

Expected: missing README contract or fixtures.

- [ ] **Step 3: Complete documentation and manual matrix**

Add the exact unscored statement, controls, event/summary paths, limitations, verification command, and correct/incorrect manual results. Record date, Godot version, Windows version, completion, and persistence result.

- [ ] **Step 4: Run GREEN and prohibited-language scan**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
rg -n -i "score|points|pass/fail|rank|recommendation" apps/incident-room/scripts apps/incident-room/scenes
```

Expected: tests pass; runtime has only explicit unscored notices and no result calculation.

- [ ] **Step 5: Commit**

```powershell
git add apps/incident-room/README.md apps/incident-room/tests/test_acceptance_paths.gd*
git commit -m "test: verify unscored candidate paths"
```

---

### Task 9: Export and smoke-test Windows

**Files:**
- Modify: `apps/incident-room/export_presets.cfg` only if required.
- Modify: `apps/incident-room/README.md` with build evidence.
- Preserve: `THIRD_PARTY_NOTICES.md`, `licenses/GODOT_LICENSE.txt`, `licenses/GODOT_COPYRIGHT.txt`.

**Interfaces:**
- Consumes: verified project and Godot 4.7.1 templates.
- Produces: ignored `dist/VibeProof-Incident-Room.exe` plus required notice files.

- [ ] **Step 1: Run clean import and tests**

Resolve `.godot/`, verify it is inside the prototype, remove it, and run combined verification.

- [ ] **Step 2: Export**

```powershell
$godot = Join-Path $env:LOCALAPPDATA 'VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path apps/incident-room --export-release 'Windows Desktop' dist/VibeProof-Incident-Room.exe
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
```

- [ ] **Step 3: Assemble notices**

Copy `THIRD_PARTY_NOTICES.md` and both engine-license files beside the executable. Assert all four distribution files exist and are nonempty, and verify the pinned engine-license hashes from the original plan.

- [ ] **Step 4: Smoke-test**

Launch the executable, complete one path, confirm `events.jsonl` and `summary.json`, and verify the visible summary is unscored. Record evidence without claiming backend scoring exists.

- [ ] **Step 5: Commit handoff documentation**

```powershell
git add apps/incident-room/README.md apps/incident-room/export_presets.cfg apps/incident-room/THIRD_PARTY_NOTICES.md apps/incident-room/licenses
git diff --cached --check
git commit -m "docs: verify the Godot candidate-flow build"
```

## Final verification gate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
git diff --check
git status --short
```

Required evidence:

- Godot reports `4.7.1.stable`.
- Headless import and every discovered suite pass.
- Correct, incorrect, persistence-fallback, and restart paths reach the unscored summary.
- Runtime event and summary data contain no scoring or recommendation fields.
- The Windows build opens and completes a session.
- Distribution notices and both engine-license files are present.
- The repository has no unexpected or uncommitted files.

## Explicitly deferred work

Do not add scoring rules, criterion evaluation, score storage, recruiter result APIs, authentication, cloud persistence, a live LLM, or employment recommendations in this plan. Those require a separate backend-scoring design after the Godot candidate flow is accepted.
