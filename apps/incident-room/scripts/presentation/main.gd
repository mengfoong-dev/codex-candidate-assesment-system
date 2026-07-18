class_name IncidentRoomMain
extends Node

const CandidateSessionScript = preload("res://scripts/domain/candidate_session.gd")
const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const UnscoredSummaryBuilderScript = preload("res://scripts/domain/unscored_summary_builder.gd")

@onready var room: Node3D = $IncidentRoom
@onready var player: Node = $IncidentRoom/Player
@onready var workspace: BrowserWorkspace = $UI/Workspace
@onready var office: OfficeLayer = $UI/OfficeLayer
@onready var notepad: Notepad = $UI/Notepad
@onready var ide_console: Node = $UI/IDEConsole
@onready var title_screen: Control = $UI/TitleScreen

## Base URL of the FastAPI grading backend. Empty = offline prototype (local unscored
## summary only); set = submit is graded by the backend and the real score is shown.
@export var backend_base_url := "https://vibeproof-backend-production.up.railway.app"

var _grader: BackendGrader
var _last_submission: Dictionary = {}
var _scenario: Dictionary = {}
var _logger_factory := Callable()
var _summary_writer := Callable()
var _logger: RefCounted
var _session: RefCounted
var _phase := "title"
# Presentation-only: "office" (walking the 3D room) vs "desk" (seated, using the PC).
var _view := "office"
var _desk_pc_open := false     # true once the desk camera has glided in and the PC UI shows
var _pre_sit := Transform3D.IDENTITY
var _current_summary: Dictionary = {}
var _session_serial := 0
var _session_id := ""
var _candidate_email := ""

# Where the player sits and the seated camera framing, at a bullpen desk in the isometric
# office. Measured from the GLB: desk top ~y=0.70, monitor at (x=-4.61, z=3.32) spanning
# y=0.69..1.12 (screen center ~0.90). The camera is first-person from the seat's eyes at
# seated height, looking +X at the monitor screen (body hidden while seated).
const DESK_SEAT := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-5.15, 0.42, 3.37))
const DESK_CAM_POS := Vector3(-5.15, 1.05, 3.34)
const DESK_CAM_LOOK := Vector3(-4.6, 0.92, 3.32)

var _desk_hud: Control
var _dialogue: DialogueBox
var _pause: PauseMenu
var _intro_shown := false
var _paused := false

func _ready() -> void:
    _build_desk_hud()
    _build_dialogue()
    _build_pause()
    _connect_signals()
    if _scenario.is_empty():
        var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
        if not loaded.ok:
            push_error("Could not load Incident Room scenario")
            return
        _scenario = loaded.scenario
    _create_fresh_session()
    _configure_static_ui()
    _set_phase("title")

func configure_dependencies(
        scenario: Dictionary,
        logger_factory: Callable = Callable(),
        summary_writer: Callable = Callable()
    ) -> void:
    _scenario = scenario.duplicate(true)
    _logger_factory = logger_factory
    _summary_writer = summary_writer
    _create_fresh_session()
    _configure_static_ui()
    _set_phase("title")

func begin_session(email: String = "") -> Dictionary:
    if _phase != "title":
        return _reject("Session can only begin from the title screen")
    _candidate_email = email.strip_edges()
    var result: Dictionary = _session.open_assessment(true)
    if result.ok:
        # Open the backend grading session now so events (incl. Codex prompts) stream live. The
        # coroutine runs in the background; events logged before it resolves are queued by the grader.
        if not backend_base_url.strip_edges().is_empty():
            _ensure_grader()
            _grader.begin(backend_base_url, _candidate_email)
        workspace.configure(_scenario)
        workspace.set_started(false)
        office.configure(_scenario)
        office.set_snapshot(_session.snapshot())
        workspace.set_started(true)
        _view = "office"
        _set_phase("room")
        _play_intro_if_needed()
    return _finish_intent(result)

func submit_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary:
    if _phase != "briefing":
        return _reject("Initial hypothesis is only available during briefing")
    var result: Dictionary = _session.record_initial_hypothesis(hypothesis_id, confidence)
    if result.ok:
        _set_phase("room")
        workspace.set_started(true)
    return _finish_intent(result)

func open_station(station_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Stations are only available inside the workspace")
    if _find_by_id(_scenario.get("stations", []), "station_id", station_id).is_empty():
        return _reject("Unknown station: %s" % station_id)
    workspace.set_active_tab("evidence")
    return {"ok": true}

func view_artifact(artifact_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Evidence is only available inside the workspace")
    return _finish_intent(_session.view_evidence(artifact_id))

func record_ai_disposition(option_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Assistant review is only available inside the workspace")
    return _finish_intent(_session.record_ai_disposition(option_id))

func open_hypothesis_panel() -> Dictionary:
    if _phase != "room":
        return _reject("Hypothesis revision is only available inside the workspace")
    if _view != "desk":
        _sit()
    _open_desk_pc()
    workspace.set_active_tab("submit")
    return {"ok": true}

func submit_revision(hypothesis_id: String, confidence: int, fact_ids: Array) -> Dictionary:
    if _phase != "room":
        return _reject("Hypothesis revision is only available inside the workspace")
    return _finish_intent(_session.revise_hypothesis(hypothesis_id, confidence, fact_ids))

func request_verification(test_id: String, remediation_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Verification is only available inside the workspace")
    return _finish_intent(_session.record_verification(test_id, remediation_id))

func submit_final(submission: Dictionary) -> Dictionary:
    if _phase != "room":
        return _reject("Final submission is only available inside the workspace")
    var result: Dictionary = _session.submit_final(submission)
    if not result.ok:
        workspace.set_submit_error(result.get("errors", []))
        return _finish_intent(result)

    var event_warning: String = _logger.persistence_warning()
    _current_summary = UnscoredSummaryBuilderScript.build(
        _scenario,
        _session.snapshot(),
        _session.ordered_events(),
        not _logger.has_persistence_warning(),
        event_warning
    )
    var summary_error := _write_summary(JSON.stringify(_current_summary, "  "))
    if summary_error != OK:
        _current_summary.saved_to_disk = false
        var summary_warning := "The unscored summary is available in memory but could not be saved to disk (error %d)." % summary_error
        _current_summary.persistence_warning = "%s%s" % [
            event_warning + "\n" if not event_warning.is_empty() else "",
            summary_warning,
        ]
    _set_phase("summary")
    workspace.show_report(_current_summary)
    _last_submission = submission.duplicate(true)
    if not backend_base_url.strip_edges().is_empty():
        _grade_with_backend()
    return _finish_intent(result)

## Fire-and-forget backend grading after the local submit. Events streamed live during the session,
## so finalize() just flushes any tail, submits, and reads the report; it falls back to a full batch
## replay if the live session never opened (offline at start).
func _grade_with_backend() -> void:
    _ensure_grader()
    if workspace.has_method("show_backend_pending"):
        workspace.show_backend_pending()
    var res: Dictionary = await _grader.finalize(
        _session.ordered_events(), _last_submission, _scenario)
    if res.get("ok", false):
        if workspace.has_method("show_backend_score"):
            workspace.show_backend_score(res)
    else:
        if workspace.has_method("show_backend_error"):
            workspace.show_backend_error(str(res.get("error", "grading unavailable")))

func restart_session() -> Dictionary:
    _create_fresh_session()
    _configure_static_ui()
    # Workspace + office reset on the next begin_session (configure()); the console and notepad
    # are persistent scene nodes that don't, so clear their per-candidate state here explicitly.
    if ide_console != null and ide_console.has_method("reset"):
        ide_console.reset()
    if notepad != null and notepad.has_method("reset"):
        notepad.reset()
    office.close()
    _paused = false
    if _pause != null:
        _pause.close()
    if _dialogue != null:
        _dialogue.dismiss()
    _view = "office"
    _desk_pc_open = false
    if player != null and player.has_method("set_seated"):
        player.set_seated(false)
    var cam := room.get_node_or_null("Camera3D")
    if cam != null and cam.has_method("clear_focus"):
        cam.clear_focus()
    _set_phase("title")
    return {"ok": true, "session_id": _session_id}

func current_phase() -> String:
    return _phase

func current_session_id() -> String:
    return _session_id

func session_snapshot() -> Dictionary:
    return _session.snapshot()

func current_summary() -> Dictionary:
    return _current_summary.duplicate(true)

func _create_fresh_session() -> void:
    if _scenario.is_empty():
        return
    _session_serial += 1
    _session_id = "candidate-%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), _session_serial]
    if _logger_factory.is_valid():
        _logger = _logger_factory.call(_session_id, _scenario.scenario_id, _scenario.scenario_version)
    else:
        _logger = EventLoggerScript.new(
            _session_id,
            _scenario.scenario_id,
            _scenario.scenario_version,
            "user://vibeproof/sessions",
            Callable()
        )
    # Stream every accepted event to the backend as it happens (no-op until a grader exists and a
    # backend session is open). Guarded so injected test doubles without the setter still work.
    if _logger.has_method("set_on_append"):
        _logger.set_on_append(_on_event_logged)
    _session = CandidateSessionScript.new(_scenario, _logger)
    _current_summary = {}
    _intro_shown = false

## EventLogger sink: forward each recorded event to the live backend client (fire-and-forget).
func _on_event_logged(event: Dictionary) -> void:
    if _grader != null:
        _grader.on_event(event)

func _ensure_grader() -> void:
    if _grader == null:
        _grader = BackendGrader.new()
        add_child(_grader)

func _connect_signals() -> void:
    title_screen.start_requested.connect(begin_session)
    workspace.initial_hypothesis_submitted.connect(submit_initial_hypothesis)
    workspace.evidence_view_requested.connect(view_artifact)
    workspace.disposition_submitted.connect(record_ai_disposition)
    workspace.revision_submitted.connect(submit_revision)
    workspace.verification_requested.connect(request_verification)
    workspace.final_submission_requested.connect(submit_final)
    workspace.restart_requested.connect(restart_session)
    workspace.leave_requested.connect(_back_to_desk)
    workspace.notepad_requested.connect(func() -> void: notepad.open_pad())
    workspace.assistant_requested.connect(_open_codex_console)
    if ide_console != null and ide_console.has_signal("prompt_submitted"):
        ide_console.prompt_submitted.connect(_on_codex_prompt)
    if ide_console != null and ide_console.has_signal("code_applied"):
        ide_console.code_applied.connect(_on_code_applied)
    notepad.closed.connect(_update_presentation)
    if player != null:
        player.interaction_requested.connect(_on_interact)
        player.nearest_station_changed.connect(_on_nearest_station_changed)
        player.hypothesis_requested.connect(open_hypothesis_panel)
    office.evidence_view_requested.connect(view_artifact)
    office.modal_changed.connect(func(_open: bool) -> void: _update_player_input())
    office.view_toggle_requested.connect(_toggle_view)
    office.senior_question_asked.connect(_on_senior_question)

func _toggle_view() -> void:
    var cam := room.get_node_or_null("Camera3D")
    if cam != null and cam.has_method("toggle_mode"):
        cam.toggle_mode()

func _configure_static_ui() -> void:
    if _scenario.is_empty():
        return
    title_screen.configure(_scenario)

# --- Office <-> desk presentation loop ---------------------------------------

func _on_interact(station_id: String) -> void:
    if _phase != "briefing" and _phase != "room":
        return
    if _view != "office" or office.is_modal_open():
        return
    match station_id:
        "my_desk":
            _sit()
        "senior":
            office.open_senior()
        _:
            office.open_station(station_id)

func _on_nearest_station_changed(station_id: String) -> void:
    office.show_hint(_prompt_for(station_id))

func _sit() -> void:
    if _phase != "briefing" and _phase != "room":
        return
    office.close()
    _view = "desk"
    _desk_pc_open = false
    # Seat the player in the chair facing the monitor with the sit pose.
    _pre_sit = player.global_transform
    player.global_transform = DESK_SEAT
    if player.has_method("set_seated"):
        player.set_seated(true)
    # Glide the camera from third-person (you see yourself sit) into a seated first-person
    # view of the desk. The PC and notepad stay closed — the desk is now an interactive hub.
    var cam := room.get_node_or_null("Camera3D")
    if cam != null and cam.has_method("focus_on"):
        cam.focus_on(Transform3D(Basis.IDENTITY, DESK_CAM_POS).looking_at(DESK_CAM_LOOK, Vector3.UP))
    _update_presentation()

func _open_desk_pc() -> void:
    if _view != "desk":
        return
    _desk_pc_open = true
    _update_presentation()

func _back_to_desk() -> void:
    # Close the PC and return to the seated first-person desk hub (still seated).
    _desk_pc_open = false
    _update_presentation()

## Open the Codex IDE console overlay, launched from the workspace's Codex tab. The console
## is PC-only now (no global hotkey), so it only opens from here while seated at the PC.
func _open_codex_console() -> void:
    if ide_console != null and ide_console.has_method("show_console"):
        ide_console.show_console()

## Log the candidate's raw AI prompt / senior question into the Proof Replay (Layer-2 review).
## Advisory only — the deterministic grader ignores these event types.
func _on_codex_prompt(text: String) -> void:
    if _session != null and (_phase == "briefing" or _phase == "room"):
        _session.record_ai_prompt(text)

## Stream the candidate's AI-edited orchestrator to the backend (mapped to its canonical path) so the
## content-aware rewrite grading evaluates the real edited code, not the seed.
func _on_code_applied(content: String) -> void:
    if _grader != null and (_phase == "briefing" or _phase == "room"):
        _grader.send_file(content)

func _on_senior_question(text: String) -> void:
    if _session != null and (_phase == "briefing" or _phase == "room"):
        _session.record_senior_question(text)

func _stand() -> void:
    if _phase != "briefing" and _phase != "room":
        return
    _view = "office"
    _desk_pc_open = false
    if player.has_method("set_seated"):
        player.set_seated(false)
    player.global_transform = _pre_sit
    var cam := room.get_node_or_null("Camera3D")
    if cam != null and cam.has_method("clear_focus"):
        cam.clear_focus()
    _update_presentation()

func _prompt_for(station_id: String) -> String:
    match station_id:
        "":
            return "Click to walk, or WASD  ·  click / press E to interact"
        "my_desk":
            return "Press E — sit at your laptop 💻"
        "senior":
            return "Press E — talk to Sam, your senior ☕"
        _:
            var station := _find_by_id(_scenario.get("stations", []), "station_id", station_id)
            return "Press E — inspect %s" % str(station.get("title", station_id))

func _set_phase(next_phase: String) -> void:
    _phase = next_phase
    _update_presentation()

func _update_presentation() -> void:
    var working := _phase == "briefing" or _phase == "room"
    var at_desk := _view == "desk"
    title_screen.visible = _phase == "title"
    room.visible = _phase != "summary"
    workspace.visible = (working and at_desk and _desk_pc_open) or _phase == "summary"
    office.visible = working and not at_desk
    if _desk_hud != null:
        _desk_hud.visible = working and at_desk and not _desk_pc_open and not notepad.visible
    if office.visible:
        office.show_hint("" if (_paused or _dialogue_active()) else _prompt_for(""))
    _update_player_input()

func _build_desk_hud() -> void:
    # The seated desk hub: buttons to open the PC, the notepad, or get up. Shown only
    # while seated at the desk with nothing open.
    _desk_hud = Control.new()
    _desk_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _desk_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    $UI.add_child(_desk_hud)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    center.offset_top = -108
    center.offset_bottom = -28
    _desk_hud.add_child(center)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    center.add_child(row)
    var pc_btn := _hud_button("💻  Open PC")
    pc_btn.pressed.connect(_open_desk_pc)
    row.add_child(pc_btn)
    var note_btn := _hud_button("📝  Notepad")
    note_btn.pressed.connect(func() -> void: notepad.open_pad())
    row.add_child(note_btn)
    var up_btn := _hud_button("⬆  Get up")
    up_btn.pressed.connect(_stand)
    row.add_child(up_btn)
    _desk_hud.visible = false

func _hud_button(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_ALL
    b.custom_minimum_size = Vector2(170, 54)
    b.add_theme_font_size_override("font_size", 16)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.16, 0.3, 0.94)
    style.set_corner_radius_all(10)
    style.set_content_margin_all(10)
    b.add_theme_stylebox_override("normal", style)
    b.add_theme_stylebox_override("hover", style)
    b.add_theme_stylebox_override("pressed", style)
    b.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9, 1))
    return b

# --- Intro dialogue + pause/reset --------------------------------------------

func _build_dialogue() -> void:
    _dialogue = DialogueBox.new()
    $UI.add_child(_dialogue)
    _dialogue.finished.connect(_on_dialogue_finished)

func _build_pause() -> void:
    _pause = PauseMenu.new()
    $UI.add_child(_pause)
    _pause.resume_requested.connect(_close_pause)
    _pause.restart_requested.connect(func() -> void:
        _close_pause()
        restart_session())

func _dialogue_active() -> bool:
    return _dialogue != null and _dialogue.is_active()

func _play_intro_if_needed() -> void:
    if _intro_shown or _dialogue == null:
        return
    _intro_shown = true
    _dialogue.play(_intro_lines())
    _update_presentation()

func _on_dialogue_finished() -> void:
    _update_presentation()

func _open_pause() -> void:
    _paused = true
    if _pause != null:
        _pause.open()
    _update_presentation()

func _close_pause() -> void:
    _paused = false
    if _pause != null:
        _pause.close()
    _update_presentation()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_cancel"):
        return
    if _dialogue_active() or (_phase != "briefing" and _phase != "room"):
        return
    if _paused:
        _close_pause()
        get_viewport().set_input_as_handled()
    elif not office.is_modal_open() and not notepad.visible and not workspace.visible:
        _open_pause()
        get_viewport().set_input_as_handled()

## Intro lines: scenario-authored `intro_dialogue` if present, else a built-in fallback.
## Every line is spoken by Sam with his portrait.
func _intro_lines() -> Array:
    var loaded: Variant = load("res://assets/ui/portrait_sam.png")
    var tex: Texture2D = loaded if loaded is Texture2D else null
    var lines: Array = []
    var scripted: Variant = _scenario.get("intro_dialogue", [])
    if scripted is Array and not (scripted as Array).is_empty():
        for entry: Variant in scripted:
            if entry is Dictionary:
                lines.append({
                    "speaker": str((entry as Dictionary).get("speaker", "Sam")),
                    "text": str((entry as Dictionary).get("text", "")),
                    "portrait": tex,
                })
    else:
        for text: String in _intro_fallback():
            lines.append({"speaker": "Sam", "text": text, "portrait": tex})
    return lines

func _intro_fallback() -> Array:
    return [
        "Morning — glad you're on. We've got a live one.",
        "Right after last night's release, VibeTube's watch page got slow. p95 latency jumped from 180 ms to about 850 ms. Viewers are feeling it.",
        "The alert fired and the logs are full of slow watch-page loads. I'm buried in the release checklist, so I'm handing this incident to you — you're on-call now.",
        "Here's how I work: don't guess. Dig up the facts first — the metrics wall, the logs, the request trace, the source. Ask me anything you need; that's what I'm here for.",
        "There's an AI copilot on your laptop too. Use it — but check what it tells you before you trust it. I want to see how you verify, not just that you prompted it.",
        "When you've got a cause you can back with evidence, propose a safe fix — with a rollback and a way to validate it. Head to your desk when you're ready.",
    ]

func _update_player_input() -> void:
    if player == null or not player.has_method("set_input_enabled"):
        return
    var can_move := (_phase == "briefing" or _phase == "room") and _view == "office" and not office.is_modal_open()
    can_move = can_move and not _paused and not _dialogue_active()
    player.set_input_enabled(can_move)
    if player.has_method("set_look_enabled"):
        # Seated at the desk hub (PC/notepad closed): let the candidate glance around, no walking.
        var can_look := (_phase == "briefing" or _phase == "room") and _view == "desk" and not _desk_pc_open
        can_look = can_look and not _paused and not _dialogue_active()
        player.set_look_enabled(can_look)

func _finish_intent(result: Dictionary) -> Dictionary:
    if _session != null and _phase != "title":
        var snapshot: Dictionary = _session.snapshot()
        workspace.refresh(snapshot)
        office.set_snapshot(snapshot)
    return result

func _write_summary(contents: String) -> Error:
    var path: String = _logger.session_directory().path_join("summary.json")
    if _summary_writer.is_valid():
        return int(_summary_writer.call(path, contents)) as Error
    var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_logger.session_directory()))
    if directory_error != OK:
        return directory_error
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(contents)
    return OK

func _find_by_id(items: Variant, field: String, requested_id: String) -> Dictionary:
    for item: Variant in items if typeof(items) == TYPE_ARRAY else []:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(field, "")) == requested_id:
            return item
    return {}

func _reject(message: String) -> Dictionary:
    return {"ok": false, "errors": PackedStringArray([message])}
