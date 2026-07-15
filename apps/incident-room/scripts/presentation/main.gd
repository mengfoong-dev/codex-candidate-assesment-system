class_name IncidentRoomMain
extends Node

const CandidateSessionScript = preload("res://scripts/domain/candidate_session.gd")
const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const UnscoredSummaryBuilderScript = preload("res://scripts/domain/unscored_summary_builder.gd")

@onready var room: Node3D = $IncidentRoom
@onready var workspace: BrowserWorkspace = $UI/Workspace
@onready var title_screen: Control = $UI/TitleScreen

var _scenario: Dictionary = {}
var _logger_factory := Callable()
var _summary_writer := Callable()
var _logger: RefCounted
var _session: RefCounted
var _phase := "title"
var _current_summary: Dictionary = {}
var _session_serial := 0
var _session_id := ""

func _ready() -> void:
    _connect_signals()
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
        workspace.configure(_scenario)
        workspace.set_started(false)
        _show_phase("briefing")
    return _finish_intent(result)

func submit_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary:
    if _phase != "briefing":
        return _reject("Initial hypothesis is only available during briefing")
    var result: Dictionary = _session.record_initial_hypothesis(hypothesis_id, confidence)
    if result.ok:
        _show_phase("room")
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
    _show_phase("summary")
    workspace.show_report(_current_summary)
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

func _connect_signals() -> void:
    title_screen.start_requested.connect(begin_session)
    workspace.initial_hypothesis_submitted.connect(submit_initial_hypothesis)
    workspace.evidence_view_requested.connect(view_artifact)
    workspace.disposition_submitted.connect(record_ai_disposition)
    workspace.revision_submitted.connect(submit_revision)
    workspace.verification_requested.connect(request_verification)
    workspace.final_submission_requested.connect(submit_final)
    workspace.restart_requested.connect(restart_session)

func _configure_static_ui() -> void:
    if _scenario.is_empty():
        return
    title_screen.configure(_scenario.get("notices", {}))

func _show_phase(next_phase: String) -> void:
    _phase = next_phase
    title_screen.visible = next_phase == "title"
    # The 3D cozy office is an optional intro backdrop shown only on the title screen.
    room.visible = next_phase == "title"
    workspace.visible = next_phase == "briefing" or next_phase == "room" or next_phase == "summary"

func _finish_intent(result: Dictionary) -> Dictionary:
    if _session != null and _phase != "title":
        workspace.refresh(_session.snapshot())
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
