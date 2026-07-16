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
@onready var title_screen: Control = $UI/TitleScreen

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

# Where the player sits at the desk (facing the monitor, legs under the desk) and the
# seated first-person camera framing the desktop. The built-in desk sits at ~(1.75, -0.5).
# Player sits behind the workstation (at +Z) facing -Z toward the monitor and the open
# room beyond. Over-the-shoulder desk framing (from outside the cutaway looking in) —
# a true in-room first-person view sees the diorama's open void, so we frame from behind.
const DESK_SEAT := Transform3D(Basis(Vector3.UP, PI), Vector3(0.3, 0.45, 2.0))
const DESK_CAM_POS := Vector3(0.3, 2.3, 4.3)
const DESK_CAM_LOOK := Vector3(0.3, 0.9, 1.1)

var _desk_hud: Control

func _ready() -> void:
    _build_desk_hud()
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

func begin_session() -> Dictionary:
    if _phase != "title":
        return _reject("Session can only begin from the title screen")
    var result: Dictionary = _session.open_assessment(true)
    if result.ok:
        workspace.configure(_scenario)
        workspace.set_started(false)
        office.configure(_scenario)
        office.set_snapshot(_session.snapshot())
        _view = "office"
        _set_phase("briefing")
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
    return _finish_intent(result)

func restart_session() -> Dictionary:
    _create_fresh_session()
    _configure_static_ui()
    office.close()
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
    _session = CandidateSessionScript.new(_scenario, _logger)
    _current_summary = {}

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
    notepad.closed.connect(_update_presentation)
    if player != null:
        player.interaction_requested.connect(_on_interact)
        player.nearest_station_changed.connect(_on_nearest_station_changed)
        player.hypothesis_requested.connect(open_hypothesis_panel)
    office.evidence_view_requested.connect(view_artifact)
    office.modal_changed.connect(func(_open: bool) -> void: _update_player_input())
    office.view_toggle_requested.connect(_toggle_view)

func _toggle_view() -> void:
    var cam := room.get_node_or_null("Camera3D")
    if cam != null and cam.has_method("toggle_mode"):
        cam.toggle_mode()

func _configure_static_ui() -> void:
    if _scenario.is_empty():
        return
    title_screen.configure(_scenario.get("notices", {}))

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
        office.show_hint(_prompt_for(""))
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

func _update_player_input() -> void:
    if player == null or not player.has_method("set_input_enabled"):
        return
    var can_move := (_phase == "briefing" or _phase == "room") and _view == "office" and not office.is_modal_open()
    player.set_input_enabled(can_move)

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
