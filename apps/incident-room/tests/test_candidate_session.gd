extends RefCounted

const CandidateSessionScript = preload("res://scripts/domain/candidate_session.gd")
const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")
const EventSchemaScript = preload("res://scripts/domain/event_schema.gd")

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(loaded.ok, "scenario fixture loads")
    if not loaded.ok:
        return t.failures

    var logger = EventLoggerScript.new(
        "candidate-session",
        loaded.scenario.scenario_id,
        loaded.scenario.scenario_version,
        "user://test-vibeproof",
        Callable(self, "_fail_write")
    )
    var session = CandidateSessionScript.new(loaded.scenario, logger)

    t.assert_true(session.open_assessment(true).ok, "assessment opens")
    t.assert_true(session.record_initial_hypothesis("redis_degradation", 40).ok, "initial hypothesis")
    t.assert_true(session.view_evidence("metrics_overview").ok, "metrics viewed")
    t.assert_true(session.view_evidence("homepage_trace").ok, "trace viewed")
    t.assert_true(session.view_evidence("homepage_orchestrator").ok, "source viewed")
    t.assert_true(session.record_ai_disposition("verify_then_adapt").ok, "AI disposition")
    t.assert_true(
        session.revise_hypothesis(
            "sequential_independent_calls",
            85,
            ["downstream_calls_sequential_in_trace"]
        ).ok,
        "hypothesis revised"
    )
    t.assert_true(
        session.record_verification(
            "correctness_regression",
            "parallelize_confirmed_independent_calls"
        ).ok,
        "correctness verification"
    )
    t.assert_true(
        session.record_verification(
            "p95_latency",
            "parallelize_confirmed_independent_calls"
        ).ok,
        "latency verification"
    )
    t.assert_true(session.submit_final(_complete_submission()).ok, "final submission")

    var snapshot: Dictionary = session.snapshot()
    t.assert_true(snapshot.completed, "session completes")
    t.assert_equal(snapshot.hypothesis_version, 2, "hypothesis version")
    t.assert_equal(snapshot.viewed_artifact_ids.size(), 3, "viewed artifact count")
    var expected_types := [
        "assessment_opened",
        "hypothesis_recorded",
        "evidence_viewed",
        "evidence_viewed",
        "evidence_viewed",
        "ai_prompt_submitted",
        "ai_response_received",
        "ai_suggestion_dispositioned",
        "hypothesis_revised",
        "test_executed",
        "test_executed",
        "decision_recorded",
        "final_submission",
    ]
    var events: Array[Dictionary] = session.ordered_events()
    t.assert_equal(events.map(func(event): return event.event_type), expected_types, "event chronology")
    for event in events:
        t.assert_equal(EventSchemaScript.validate(event), PackedStringArray(), "event remains unscored")

    var rejected_logger = EventLoggerScript.new(
        "rejected-session",
        loaded.scenario.scenario_id,
        loaded.scenario.scenario_version,
        "user://test-vibeproof",
        Callable(self, "_fail_write")
    )
    var rejected = CandidateSessionScript.new(loaded.scenario, rejected_logger)
    t.assert_false(rejected.view_evidence("metrics_overview").ok, "evidence blocked before briefing")
    t.assert_true(rejected.open_assessment(true).ok, "rejected fixture opens")
    t.assert_false(rejected.record_initial_hypothesis("missing", 50).ok, "unknown hypothesis rejected")
    t.assert_false(rejected.record_initial_hypothesis("redis_degradation", 101).ok, "invalid confidence rejected")
    t.assert_true(rejected.record_initial_hypothesis("redis_degradation", 50).ok, "valid hypothesis accepted")
    t.assert_false(rejected.submit_final({"root_cause_id": "cpu_saturation"}).ok, "incomplete submission rejected")
    t.assert_equal(rejected.ordered_events().size(), 2, "rejected intents do not write events")

    # Layer-2 review: the candidate's raw prompt/question text is captured as (unscored) events.
    t.assert_true(rejected.record_senior_question("what changed in the release?").ok, "senior question logs")
    t.assert_true(rejected.record_ai_prompt("parallelize the awaits safely?").ok, "ai prompt logs")
    var late_types := rejected.ordered_events().map(func(e): return e.event_type)
    t.assert_true(late_types.has("candidate_senior_question"), "senior question recorded for Proof Replay")
    t.assert_true(late_types.has("candidate_ai_prompt"), "ai prompt recorded for Proof Replay")

    # Station visits log once per station_id and are a no-op on repeat visits (dedupe).
    var visit_count_before := rejected.ordered_events().size()
    var first_visit: Dictionary = rejected.record_station_visit("observability_wall", "investigation", "Observability Wall")
    t.assert_true(first_visit.ok and not first_visit.get("skipped", false), "first station visit logs")
    t.assert_equal(rejected.ordered_events().size(), visit_count_before + 1, "first visit appends one event")
    var repeat_visit: Dictionary = rejected.record_station_visit("observability_wall", "investigation", "Observability Wall")
    t.assert_true(repeat_visit.ok and repeat_visit.get("skipped", false), "repeat station visit is skipped")
    t.assert_equal(rejected.ordered_events().size(), visit_count_before + 1, "repeat visit does not append another event")

    return t.failures

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

func _fail_write(_path: String, _line: String) -> Error:
    return ERR_CANT_CREATE
