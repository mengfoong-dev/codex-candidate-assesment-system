class_name IncidentRoomMain
extends Node

const CandidateSessionScript = preload("res://scripts/domain/candidate_session.gd")
const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const UnscoredSummaryBuilderScript = preload("res://scripts/domain/unscored_summary_builder.gd")

@onready var room: Node3D = $IncidentRoom
@onready var player: CharacterBody3D = $IncidentRoom/Player
@onready var hud: Control = $UI/HUD
@onready var station_hint: Label = $UI/HUD/Margin/Layout/StationHint
@onready var persistence_warning: Label = $UI/HUD/Margin/Layout/PersistenceWarning
@onready var message_label: Label = $UI/HUD/Margin/Layout/Message
@onready var title_screen: Control = $UI/TitleScreen
@onready var briefing_panel: Control = $UI/BriefingPanel
@onready var investigation_panel: Control = $UI/InvestigationPanel
@onready var hypothesis_panel: Control = $UI/HypothesisPanel
@onready var release_panel: Control = $UI/ReleasePanel
@onready var summary_panel: Control = $UI/UnscoredSummary
@onready var browser: BrowserWorkspace = $UI/BrowserWorkspace

const ROOM_TABS := [
    {"key": "observability_wall", "label": "Observability"},
    {"key": "developer_desk", "label": "Developer"},
    {"key": "release_console", "label": "Release"},
    {"key": "hypothesis", "label": "Hypothesis"},
]
const BRIEF_TABS := [{"key": "brief", "label": "Brief"}]
const REPORT_TABS := [{"key": "report", "label": "Report"}]

var _scenario: Dictionary = {}
var _logger_factory := Callable()
var _summary_writer := Callable()
var _logger: RefCounted
var _session: RefCounted
var _phase := "title"
var _current_station_id := ""
var _current_summary: Dictionary = {}
var _session_serial := 0
var _session_id := ""

func _ready() -> void:
    _connect_signals()
    _setup_browser()
    if _scenario.is_empty():
        var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
        if not loaded.ok:
            push_error("Could not load Incident Room scenario")
            return
        _scenario = loaded.scenario
    _create_fresh_session()
    _configure_static_ui()
    _show_phase("title")

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
    _show_phase("title")

func begin_session() -> Dictionary:
    if _phase != "title":
        return _reject("Session can only begin from the title screen")
    var result: Dictionary = _session.open_assessment(true)
    if result.ok:
        briefing_panel.configure(_scenario)
        _show_phase("briefing")
    return _finish_intent(result)

func submit_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary:
    if _phase != "briefing":
        return _reject("Initial hypothesis is only available during briefing")
    var result: Dictionary = _session.record_initial_hypothesis(hypothesis_id, confidence)
    if result.ok:
        _show_phase("room")
    return _finish_intent(result)

func open_station(station_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Stations are only available inside the Incident Room")
    if _find_by_id(_scenario.get("stations", []), "station_id", station_id).is_empty():
        return _reject("Unknown station: %s" % station_id)
    _current_station_id = station_id
    if station_id == "release_console":
        release_panel.configure(_scenario, _session.snapshot())
        _show_modal(release_panel)
    else:
        investigation_panel.configure(station_id, _scenario, _session.snapshot())
        _show_modal(investigation_panel)
    return {"ok": true}

func view_artifact(artifact_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Evidence is only available inside the Incident Room")
    var result: Dictionary = _session.view_evidence(artifact_id)
    if result.ok and not _current_station_id.is_empty():
        investigation_panel.configure(_current_station_id, _scenario, _session.snapshot())
    return _finish_intent(result)

func record_ai_disposition(option_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Assistant review is only available inside the Incident Room")
    var result: Dictionary = _session.record_ai_disposition(option_id)
    return _finish_intent(result)

func open_hypothesis_panel() -> Dictionary:
    if _phase != "room":
        return _reject("Hypothesis revision is only available inside the Incident Room")
    hypothesis_panel.configure(_scenario, _session.snapshot())
    _show_modal(hypothesis_panel)
    return {"ok": true}

func submit_revision(hypothesis_id: String, confidence: int, fact_ids: Array) -> Dictionary:
    if _phase != "room":
        return _reject("Hypothesis revision is only available inside the Incident Room")
    var result: Dictionary = _session.revise_hypothesis(hypothesis_id, confidence, fact_ids)
    if result.ok:
        # Stay on the Hypothesis tab and reflect the revised state.
        hypothesis_panel.configure(_scenario, _session.snapshot())
    return _finish_intent(result)

func request_verification(test_id: String, remediation_id: String) -> Dictionary:
    if _phase != "room":
        return _reject("Verification is only available inside the Incident Room")
    var result: Dictionary = _session.record_verification(test_id, remediation_id)
    if result.ok:
        release_panel.configure(_scenario, _session.snapshot())
        _show_modal(release_panel)
    return _finish_intent(result)

func submit_final(submission: Dictionary) -> Dictionary:
    if _phase != "room":
        return _reject("Final submission is only available inside the Incident Room")
    var result: Dictionary = _session.submit_final(submission)
    if not result.ok:
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
    summary_panel.configure(_current_summary)
    _show_phase("summary")
    return _finish_intent(result)

func restart_session() -> Dictionary:
    _create_fresh_session()
    _configure_static_ui()
    _show_phase("title")
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
    _current_station_id = ""

func _connect_signals() -> void:
    title_screen.start_requested.connect(begin_session)
    briefing_panel.hypothesis_submitted.connect(submit_initial_hypothesis)
    player.interaction_requested.connect(open_station)
    player.nearest_station_changed.connect(_on_nearest_station_changed)
    player.hypothesis_requested.connect(open_hypothesis_panel)
    investigation_panel.artifact_viewed.connect(view_artifact)
    investigation_panel.ai_disposition_selected.connect(record_ai_disposition)
    hypothesis_panel.revision_submitted.connect(submit_revision)
    release_panel.verification_requested.connect(request_verification)
    release_panel.final_submission_requested.connect(submit_final)
    summary_panel.restart_requested.connect(restart_session)
    for panel: Control in [investigation_panel, hypothesis_panel, release_panel]:
        panel.visibility_changed.connect(_sync_player_input)

func _setup_browser() -> void:
    # Host the existing assessment panels inside the browser so the desktop reads
    # like a candidate opening tabs in a web app. Reparenting keeps the cached
    # references and the coordinator's existing show/hide logic intact.
    var host := browser.content_root()
    for panel: Control in [briefing_panel, investigation_panel, hypothesis_panel, release_panel, summary_panel]:
        panel.reparent(host, false)
    browser.tab_activated.connect(_on_tab_activated)

func _on_tab_activated(key: String) -> void:
    match key:
        "observability_wall", "developer_desk", "release_console":
            open_station(key)
        "hypothesis":
            open_hypothesis_panel()

func _configure_static_ui() -> void:
    if _scenario.is_empty():
        return
    title_screen.configure(_scenario.get("notices", {}))
    persistence_warning.text = ""
    message_label.text = ""
    station_hint.text = "E interact • 1/2/3 stations • H revise hypothesis"
    browser.set_url("🔒  vibeproof.app / incident / %s" % str(_scenario.get("scenario_id", "session")))

func _show_phase(next_phase: String) -> void:
    _phase = next_phase
    title_screen.visible = next_phase == "title"
    # The 3D office is the sit-down backdrop behind the title; the browser fills
    # the screen once the candidate is working.
    room.visible = next_phase == "title"
    browser.visible = next_phase == "briefing" or next_phase == "room" or next_phase == "summary"
    hud.visible = false
    briefing_panel.visible = next_phase == "briefing"
    summary_panel.visible = next_phase == "summary"
    if next_phase != "room":
        investigation_panel.hide()
        hypothesis_panel.hide()
        release_panel.hide()
    match next_phase:
        "briefing":
            browser.set_tabs(BRIEF_TABS)
            browser.set_active_tab("brief")
        "room":
            browser.set_tabs(ROOM_TABS)
            open_station("observability_wall")
            browser.set_active_tab("observability_wall")
        "summary":
            browser.set_tabs(REPORT_TABS)
            browser.set_active_tab("report")
    _sync_player_input()

func _show_modal(panel: Control) -> void:
    for candidate: Control in [investigation_panel, hypothesis_panel, release_panel]:
        candidate.visible = candidate == panel
    _sync_player_input()

func _close_modals() -> void:
    investigation_panel.hide()
    hypothesis_panel.hide()
    release_panel.hide()
    _sync_player_input()

func _sync_player_input() -> void:
    if player == null:
        return
    var modal_open := investigation_panel.visible or hypothesis_panel.visible or release_panel.visible
    player.set_input_enabled(_phase == "room" and not modal_open)

func _on_nearest_station_changed(station_id: String) -> void:
    if station_id.is_empty():
        station_hint.text = "E interact • 1/2/3 stations • H revise hypothesis"
        return
    var station := _find_by_id(_scenario.get("stations", []), "station_id", station_id)
    station_hint.text = "E open %s • 1/2/3 quick access • H revise hypothesis" % station.get("title", station_id)

func _finish_intent(result: Dictionary) -> Dictionary:
    if not result.get("ok", false):
        var errors: Variant = result.get("errors", [])
        message_label.text = str(errors[0]) if not errors.is_empty() else "That action is not available."
    else:
        message_label.text = ""
    persistence_warning.text = _logger.persistence_warning()
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
