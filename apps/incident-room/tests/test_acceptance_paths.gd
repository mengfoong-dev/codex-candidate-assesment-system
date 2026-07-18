extends RefCounted

const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const FORBIDDEN_KEYS := ["score", "points", "criteria", "pass", "rank", "capability", "recommendation"]

var _event_write_error: Error = OK
var _summary_write_error: Error = OK

func run(tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(loaded.ok, "acceptance scenario loads")
    if not loaded.ok:
        return t.failures

    _event_write_error = OK
    _summary_write_error = OK
    var evidence_based := _new_main(tree, loaded.scenario)
    _drive_evidence_based_path(evidence_based)
    t.assert_equal(evidence_based.current_phase(), "summary", "evidence-based path reaches summary")
    t.assert_equal(evidence_based.current_summary().final_submission.root_cause.option_id, "sequential_independent_calls", "evidence-based choice is preserved")
    t.assert_equal(_find_forbidden_key(evidence_based.current_summary()), "", "evidence-based summary has no evaluation fields")

    var unsupported := _new_main(tree, loaded.scenario)
    _drive_unsupported_cpu_path(unsupported)
    t.assert_equal(unsupported.current_phase(), "summary", "unsupported CPU path reaches summary")
    t.assert_equal(unsupported.current_summary().final_submission.root_cause.option_id, "cpu_saturation", "unsupported root cause is preserved without evaluation")
    t.assert_equal(unsupported.current_summary().final_submission.remediation.option_id, "scale_cpu", "unsupported remediation is preserved without evaluation")
    t.assert_equal(_find_forbidden_key(unsupported.current_summary()), "", "unsupported summary has no evaluation fields")

    _event_write_error = ERR_CANT_CREATE
    _summary_write_error = ERR_CANT_CREATE
    var fallback := _new_main(tree, loaded.scenario)
    _drive_unsupported_cpu_path(fallback)
    t.assert_equal(fallback.current_phase(), "summary", "persistence-fallback path reaches summary")
    t.assert_false(fallback.current_summary().saved_to_disk, "fallback summary reports in-memory state")
    t.assert_true(not fallback.current_summary().persistence_warning.is_empty(), "fallback summary displays warning")

    var old_session_id: String = fallback.current_session_id()
    t.assert_true(fallback.restart_session().ok, "acceptance session restarts")
    t.assert_equal(fallback.current_phase(), "title", "restart returns to title")
    t.assert_true(fallback.current_session_id() != old_session_id, "restart changes session ID")
    t.assert_equal(fallback.session_snapshot().viewed_artifact_ids, [], "restart clears candidate evidence")

    var readme := FileAccess.get_file_as_string("res://README.md")
    t.assert_true(readme.contains("The current prototype is intentionally unscored."), "README states the unscored boundary")

    for main: Node in [evidence_based, unsupported, fallback]:
        main.queue_free()
    return t.failures

func _new_main(tree: SceneTree, scenario: Dictionary) -> Node:
    var main: Node = load("res://scenes/main/main.tscn").instantiate()
    tree.root.add_child(main)
    main.configure_dependencies(
        scenario,
        Callable(self, "_logger_factory"),
        Callable(self, "_summary_writer")
    )
    main.backend_base_url = ""  # hermetic: never touch the live grading backend from tests
    return main

func _drive_evidence_based_path(main: Node) -> void:
    main.begin_session()
    main.submit_initial_hypothesis("redis_degradation", 40)
    main.view_artifact("metrics_overview")
    main.view_artifact("homepage_trace")
    main.view_artifact("homepage_orchestrator")
    main.record_ai_disposition("verify_then_adapt")
    main.submit_revision("sequential_independent_calls", 85, ["downstream_calls_sequential_in_trace"])
    main.request_verification("correctness_regression", "parallelize_confirmed_independent_calls")
    main.request_verification("p95_latency", "parallelize_confirmed_independent_calls")
    main.submit_final({
        "root_cause_id": "sequential_independent_calls",
        "evidence_ids": ["homepage_trace", "homepage_orchestrator"],
        "remediation_id": "parallelize_confirmed_independent_calls",
        "risk_ids": ["partial_failure_behavior"],
        "assumption_ids": ["calls_are_independent"],
        "validation_test_ids": ["correctness_regression", "p95_latency"],
        "rollback_id": "restore_sequential_orchestration",
        "final_confidence": 90,
        "rationale": "Trace and source show independent sequential waits.",
    })

func _drive_unsupported_cpu_path(main: Node) -> void:
    main.begin_session()
    main.submit_initial_hypothesis("cpu_saturation", 75)
    main.view_artifact("metrics_overview")
    main.request_verification("correctness_regression", "scale_cpu")
    main.submit_final({
        "root_cause_id": "cpu_saturation",
        "evidence_ids": ["metrics_overview"],
        "remediation_id": "scale_cpu",
        "risk_ids": ["none_identified"],
        "assumption_ids": ["none"],
        "validation_test_ids": ["correctness_regression"],
        "rollback_id": "rollback_release",
        "final_confidence": 75,
        "rationale": "CPU scaling is my selected response.",
    })

func _logger_factory(session_id: String, scenario_id: String, scenario_version: String) -> RefCounted:
    return EventLoggerScript.new(
        session_id,
        scenario_id,
        scenario_version,
        "user://test-vibeproof-acceptance",
        Callable(self, "_event_writer")
    )

func _event_writer(_path: String, _line: String) -> Error:
    return _event_write_error

func _summary_writer(_path: String, _contents: String) -> Error:
    return _summary_write_error

func _find_forbidden_key(value: Variant) -> String:
    if typeof(value) == TYPE_DICTIONARY:
        for key: Variant in value:
            var key_text := str(key).to_lower()
            if FORBIDDEN_KEYS.has(key_text):
                return key_text
            var nested := _find_forbidden_key(value[key])
            if not nested.is_empty():
                return nested
    elif typeof(value) == TYPE_ARRAY:
        for child: Variant in value:
            var nested := _find_forbidden_key(child)
            if not nested.is_empty():
                return nested
    return ""
