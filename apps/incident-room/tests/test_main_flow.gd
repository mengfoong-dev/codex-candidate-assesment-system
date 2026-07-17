extends RefCounted

const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"

func run(tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(loaded.ok, "main-flow scenario loads")
    var packed: PackedScene = load(MAIN_SCENE_PATH)
    t.assert_true(packed != null, "main scene loads")
    if not loaded.ok or packed == null:
        return t.failures

    var main: Node = packed.instantiate()
    tree.root.add_child(main)
    t.assert_true(main.has_method("configure_dependencies"), "main supports dependency injection")
    if not main.has_method("configure_dependencies"):
        main.queue_free()
        return t.failures

    main.configure_dependencies(
        loaded.scenario,
        Callable(self, "_memory_logger_factory"),
        Callable(self, "_fail_summary_write")
    )
    t.assert_equal(main.current_phase(), "title", "flow starts at title")
    t.assert_false(main.view_artifact("metrics_overview").ok, "room intents are rejected before the session starts")
    t.assert_equal(main.current_phase(), "title", "rejected intent does not change phase")

    t.assert_true(main.begin_session().ok, "session begins")
    t.assert_equal(main.current_phase(), "room", "title advances straight to the open workspace (no Brief gate)")

    t.assert_true(main.open_station("observability_wall").ok, "observability station opens")
    t.assert_true(main.view_artifact("metrics_overview").ok, "metrics viewed")
    t.assert_true(main.view_artifact("homepage_trace").ok, "trace viewed")
    t.assert_true(main.open_station("developer_desk").ok, "developer station opens")
    t.assert_true(main.view_artifact("homepage_orchestrator").ok, "source viewed")
    t.assert_true(main.record_ai_disposition("verify_then_adapt").ok, "AI disposition recorded")
    t.assert_true(main.open_hypothesis_panel().ok, "revision panel opens")
    t.assert_true(main.submit_revision(
        "sequential_independent_calls",
        85,
        ["downstream_calls_sequential_in_trace"]
    ).ok, "hypothesis revision accepted")
    t.assert_true(main.open_station("release_console").ok, "release station opens")
    t.assert_true(main.request_verification(
        "correctness_regression",
        "parallelize_confirmed_independent_calls"
    ).ok, "correctness verification accepted")
    t.assert_true(main.request_verification(
        "p95_latency",
        "parallelize_confirmed_independent_calls"
    ).ok, "latency verification accepted")
    t.assert_true(main.submit_final(_complete_submission()).ok, "final submission accepted")
    t.assert_equal(main.current_phase(), "summary", "room advances to summary")
    t.assert_equal(main.current_summary().label, "Unscored prototype summary", "summary remains explicitly unscored")
    t.assert_false(main.current_summary().saved_to_disk, "injected persistence failure is visible")

    var first_session_id: String = main.current_session_id()
    t.assert_true(main.restart_session().ok, "session restarts")
    t.assert_equal(main.current_phase(), "title", "restart returns to title")
    t.assert_true(main.current_session_id() != first_session_id, "restart creates a new session ID")
    t.assert_false(main.session_snapshot().opened, "restart state is unopened")
    t.assert_equal(main.session_snapshot().viewed_artifact_ids, [], "restart clears evidence state")

    main.queue_free()
    return t.failures

func _memory_logger_factory(session_id: String, scenario_id: String, scenario_version: String) -> RefCounted:
    return EventLoggerScript.new(
        session_id,
        scenario_id,
        scenario_version,
        "user://test-vibeproof-main",
        Callable(self, "_fail_event_write")
    )

func _fail_event_write(_path: String, _line: String) -> Error:
    return ERR_CANT_CREATE

func _fail_summary_write(_path: String, _contents: String) -> Error:
    return ERR_CANT_CREATE

func _complete_submission() -> Dictionary:
    return {
        "root_cause_id": "sequential_independent_calls",
        "evidence_ids": ["homepage_trace", "homepage_orchestrator"],
        "remediation_id": "parallelize_confirmed_independent_calls",
        "risk_ids": ["partial_failure_behavior"],
        "assumption_ids": ["calls_are_independent"],
        "validation_test_ids": ["correctness_regression", "p95_latency"],
        "rollback_id": "restore_sequential_orchestration",
        "final_confidence": 90,
        "rationale": "Trace and source show independent sequential waits.",
    }
