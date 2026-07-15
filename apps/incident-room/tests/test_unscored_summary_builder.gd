extends RefCounted

const CandidateSessionScript = preload("res://scripts/domain/candidate_session.gd")
const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const UnscoredSummaryBuilderScript = preload("res://scripts/domain/unscored_summary_builder.gd")

const FORBIDDEN_KEYS := [
    "score",
    "points",
    "criteria",
    "pass",
    "rank",
    "capability",
    "recommendation",
]

const SUMMARY_KEYS: Array[String] = [
    "label",
    "session_id",
    "scenario_id",
    "scenario_version",
    "completed",
    "saved_to_disk",
    "persistence_warning",
    "initial_hypothesis",
    "final_hypothesis",
    "evidence_timeline",
    "ai_disposition",
    "verification_actions",
    "final_submission",
    "notices",
]

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(loaded.ok, "scenario fixture loads")
    if not loaded.ok:
        return t.failures

    var logger = EventLoggerScript.new(
        "summary-session",
        loaded.scenario.scenario_id,
        loaded.scenario.scenario_version,
        "user://test-vibeproof",
        Callable(self, "_fail_write")
    )
    var session = CandidateSessionScript.new(loaded.scenario, logger)
    _complete_candidate_flow(session)

    var summary: Dictionary = UnscoredSummaryBuilderScript.build(
        loaded.scenario,
        session.snapshot(),
        session.ordered_events(),
        true,
        ""
    )

    t.assert_has_keys(summary, SUMMARY_KEYS, "summary contract")
    t.assert_equal(summary.label, "Unscored prototype summary", "summary is explicitly unscored")
    t.assert_true(summary.completed, "completed state is copied")
    t.assert_true(summary.saved_to_disk, "saved state is copied")
    t.assert_equal(summary.initial_hypothesis.label, "Redis cache degradation is driving the latency increase.", "initial hypothesis label")
    t.assert_equal(summary.final_hypothesis.label, "Independent homepage lookups are waiting sequentially.", "final hypothesis label")
    t.assert_equal(summary.evidence_timeline.size(), 4, "repeated evidence remains in the timeline")
    t.assert_equal(summary.evidence_timeline[0].artifact_id, "metrics_overview", "first evidence chronology")
    t.assert_equal(summary.evidence_timeline[1].artifact_id, "metrics_overview", "repeated evidence chronology")
    t.assert_equal(summary.evidence_timeline[2].title, "Homepage Request Trace", "evidence title mapping")
    t.assert_equal(summary.ai_disposition.option_id, "verify_then_adapt", "AI disposition copied")
    t.assert_equal(summary.ai_disposition.disposition, "modified", "AI disposition detail")
    t.assert_equal(summary.verification_actions[0].test.title, "Correctness regression", "test title mapping")
    t.assert_equal(summary.final_submission.root_cause.label, "Sequential independent homepage calls", "root cause label mapping")
    t.assert_equal(summary.final_submission.remediation.option_id, "parallelize_confirmed_independent_calls", "remediation copied")
    t.assert_equal(summary.final_submission.validation_tests.size(), 2, "validation tests copied")
    t.assert_equal(_find_forbidden_key(summary), "", "summary contains no scoring or evaluation keys")

    var alternate_snapshot: Dictionary = session.snapshot()
    alternate_snapshot.final_submission.root_cause_id = "cpu_saturation"
    alternate_snapshot.final_submission.remediation_id = "scale_cpu"
    var alternate: Dictionary = UnscoredSummaryBuilderScript.build(
        loaded.scenario,
        alternate_snapshot,
        session.ordered_events(),
        true,
        ""
    )
    t.assert_equal(alternate.final_submission.root_cause.label, "Application CPU saturation", "alternate choice is represented")
    t.assert_equal(alternate.final_submission.remediation.label, "Scale application CPU capacity", "alternate remediation is represented")
    t.assert_equal(_find_forbidden_key(alternate), "", "alternate choices are not evaluated")

    var warning_summary: Dictionary = UnscoredSummaryBuilderScript.build(
        loaded.scenario,
        session.snapshot(),
        session.ordered_events(),
        false,
        logger.persistence_warning()
    )
    t.assert_false(warning_summary.saved_to_disk, "persistence failure is visible")
    t.assert_true(not warning_summary.persistence_warning.is_empty(), "persistence warning is copied")
    t.assert_equal(_find_forbidden_key(warning_summary), "", "warning summary remains unscored")

    return t.failures

func _complete_candidate_flow(session: RefCounted) -> void:
    session.open_assessment(true)
    session.record_initial_hypothesis("redis_degradation", 40)
    session.view_evidence("metrics_overview")
    session.view_evidence("metrics_overview")
    session.view_evidence("homepage_trace")
    session.view_evidence("homepage_orchestrator")
    session.record_ai_disposition("verify_then_adapt")
    session.revise_hypothesis(
        "sequential_independent_calls",
        85,
        ["downstream_calls_sequential_in_trace"]
    )
    session.record_verification("correctness_regression", "parallelize_confirmed_independent_calls")
    session.record_verification("p95_latency", "parallelize_confirmed_independent_calls")
    session.submit_final({
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

func _find_forbidden_key(value: Variant, path: String = "") -> String:
    if typeof(value) == TYPE_DICTIONARY:
        for key: Variant in value:
            var key_text := str(key).to_lower()
            var child_path := "%s.%s" % [path, key_text]
            if FORBIDDEN_KEYS.has(key_text):
                return child_path
            var nested := _find_forbidden_key(value[key], child_path)
            if not nested.is_empty():
                return nested
    elif typeof(value) == TYPE_ARRAY:
        for index in value.size():
            var nested := _find_forbidden_key(value[index], "%s[%d]" % [path, index])
            if not nested.is_empty():
                return nested
    return ""

func _fail_write(_path: String, _line: String) -> Error:
    return ERR_CANT_CREATE
