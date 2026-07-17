extends RefCounted

const ScenarioLoader = preload("res://scripts/domain/scenario_loader.gd")
const TestSupport = preload("res://tests/test_support.gd")

# NOTE: frontend-only contract. Decoy screens (cache/scaling/changelog) were added to the
# frontend scenario for discernment; the deployed backend grader still uses its own 4-artifact
# scenario, so decoy views are dropped grader-side until the backend is synced (see the
# streamlined-fix-first-flow spec). Keep this list in step with data/scenarios only.
const EXPECTED_FACT_IDS: Array[String] = [
    "homepage_p95_increased",
    "cpu_not_saturated",
    "database_healthy",
    "recommendation_service_healthy",
    "redis_hit_rate_low",
    "requests_complete_without_errors",
    "downstream_calls_successful",
    "no_database_timeout",
    "no_cpu_exhaustion",
    "downstream_calls_sequential_in_trace",
    "downstream_waits_accumulate",
    "sequential_awaits_in_code",
    "calls_are_independent_in_code",
    "required_ordering_must_remain",
    "redis_hit_rate_baseline",
    "redis_healthy_otherwise",
    "cpu_headroom_ample",
    "no_scaling_events",
    "release_added_recommendations_call",
    "no_infra_or_db_change",
]

const EXPECTED_CRITERION_POINTS := {
    "trace_before_change": 10,
    "healthy_signals_used": 10,
    "sequential_source_identified": 10,
    "independence_checked": 10,
    "dual_validation_selected": 10,
    "revised_after_contradiction": 10,
    "unsupported_cpu_scaling": -10,
    "unverified_ai_acceptance": -10,
    "diagnosis_without_evidence": -15,
}

func run(_tree: SceneTree) -> Array[String]:
    var t := TestSupport.new()
    var result := ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(result.ok, "scenario should load: %s" % result.errors)
    if result.ok:
        var scenario: Dictionary = result.scenario
        _assert_frozen_contract(t, scenario)
        _assert_normalized_integers(t, scenario)
        _assert_negative_contracts(t, scenario)
    return t.failures

func _assert_frozen_contract(t: RefCounted, scenario: Dictionary) -> void:
    t.assert_equal(scenario.scenario_id, "homepage_latency", "scenario id")
    t.assert_equal(scenario.scenario_version, "1.0.0", "scenario version")
    t.assert_equal(scenario.stations.map(func(item): return item.station_id), ["observability_wall", "developer_desk", "release_console"], "station ids")
    t.assert_equal(scenario.artifacts.size(), 7, "artifact count (4 real + 3 decoys)")
    var fact_ids: Array[String] = []
    for artifact in scenario.artifacts:
        for fact in artifact.facts:
            fact_ids.append(fact.fact_id)
    t.assert_equal(fact_ids, EXPECTED_FACT_IDS, "stable fact ids")
    t.assert_equal(scenario.submission_options.root_causes.map(func(item): return item.option_id), ["redis_degradation", "database_slowdown", "cpu_saturation", "sequential_independent_calls", "insufficient_evidence"], "root-cause ids")
    t.assert_equal(scenario.ai_interaction.response.model_label, "scripted_offline_v1", "scripted AI label")
    t.assert_equal(scenario.submission_options.required_validation_test_ids, ["correctness_regression", "p95_latency"], "required validations")
    t.assert_equal(scenario.scoring.criteria.size(), 9, "scoring criterion count")
    var criterion_points := {}
    for criterion in scenario.scoring.criteria:
        criterion_points[criterion.criterion_id] = criterion.configured_points
    t.assert_equal(criterion_points, EXPECTED_CRITERION_POINTS, "frozen scoring criteria")

func _assert_normalized_integers(t: RefCounted, scenario: Dictionary) -> void:
    for station in scenario.stations:
        t.assert_equal(typeof(station.quick_key), TYPE_INT, "station quick key is normalized")
    t.assert_equal(typeof(scenario.ai_interaction.response.latency_ms), TYPE_INT, "AI latency is normalized")
    for criterion in scenario.scoring.criteria:
        t.assert_equal(typeof(criterion.configured_points), TYPE_INT, "criterion points are normalized")

func _assert_negative_contracts(t: RefCounted, scenario: Dictionary) -> void:
    var duplicate_station: Dictionary = scenario.duplicate(true)
    duplicate_station.stations.append(duplicate_station.stations[0].duplicate(true))
    _assert_invalid(t, duplicate_station, "Duplicate station id: observability_wall", "duplicate station")

    var duplicate_hypothesis: Dictionary = scenario.duplicate(true)
    duplicate_hypothesis.hypotheses.append(duplicate_hypothesis.hypotheses[0].duplicate(true))
    _assert_invalid(t, duplicate_hypothesis, "Duplicate hypothesis id: redis_degradation", "duplicate hypothesis")

    var duplicate_artifact: Dictionary = scenario.duplicate(true)
    duplicate_artifact.artifacts.append(duplicate_artifact.artifacts[0].duplicate(true))
    _assert_invalid(t, duplicate_artifact, "Duplicate artifact id: metrics_overview", "duplicate artifact")

    var duplicate_fact: Dictionary = scenario.duplicate(true)
    duplicate_fact.artifacts[1].facts.append(duplicate_fact.artifacts[0].facts[0].duplicate(true))
    _assert_invalid(t, duplicate_fact, "Duplicate fact id: homepage_p95_increased", "duplicate fact")

    var duplicate_ai_option: Dictionary = scenario.duplicate(true)
    duplicate_ai_option.ai_interaction.dispositions.append(duplicate_ai_option.ai_interaction.dispositions[0].duplicate(true))
    _assert_invalid(t, duplicate_ai_option, "Duplicate AI disposition id: accept_immediately", "duplicate AI option")

    var duplicate_test: Dictionary = scenario.duplicate(true)
    duplicate_test.tests.append(duplicate_test.tests[0].duplicate(true))
    _assert_invalid(t, duplicate_test, "Duplicate test id: correctness_regression", "duplicate test")

    var duplicate_choice: Dictionary = scenario.duplicate(true)
    duplicate_choice.submission_options.remediations.append(duplicate_choice.submission_options.remediations[0].duplicate(true))
    _assert_invalid(t, duplicate_choice, "Duplicate remediation id: parallelize_confirmed_independent_calls", "duplicate choice")

    var duplicate_criterion: Dictionary = scenario.duplicate(true)
    duplicate_criterion.scoring.criteria.append(duplicate_criterion.scoring.criteria[0].duplicate(true))
    _assert_invalid(t, duplicate_criterion, "Duplicate criterion id: trace_before_change", "duplicate criterion")

    var unknown_station: Dictionary = scenario.duplicate(true)
    unknown_station.artifacts[0].station_id = "missing_station"
    _assert_invalid(t, unknown_station, "Artifact references unknown station: missing_station", "unknown artifact station")

    var dangling_ai_artifact: Dictionary = scenario.duplicate(true)
    dangling_ai_artifact.ai_interaction.prompt.referenced_context_ids = ["missing_artifact"]
    _assert_invalid(t, dangling_ai_artifact, "AI prompt references unknown artifact: missing_artifact", "dangling AI artifact")

    var dangling_required_test: Dictionary = scenario.duplicate(true)
    dangling_required_test.submission_options.required_validation_test_ids = ["missing_test"]
    _assert_invalid(t, dangling_required_test, "Required validation references unknown test: missing_test", "dangling required test")

    var dangling_remediation_result: Dictionary = scenario.duplicate(true)
    dangling_remediation_result.tests[0].results_by_remediation["missing_remediation"] = {"actual_result": "Unavailable.", "status": "unavailable"}
    _assert_invalid(t, dangling_remediation_result, "Test result references unknown remediation: missing_remediation", "dangling remediation result")

    var wrong_quick_keys: Dictionary = scenario.duplicate(true)
    wrong_quick_keys.stations[0].quick_key = 4
    _assert_invalid(t, wrong_quick_keys, "Station quick keys must be exactly 1, 2, and 3", "invalid station quick keys")

    var negative_latency: Dictionary = scenario.duplicate(true)
    negative_latency.ai_interaction.response.latency_ms = -1
    _assert_invalid(t, negative_latency, "AI response latency must be non-negative", "negative AI latency")

    var malformed_ai: Dictionary = scenario.duplicate(true)
    malformed_ai.ai_interaction = "invalid"
    var malformed_ai_result := _load_fixture(malformed_ai)
    t.assert_false(malformed_ai_result.ok, "non-object AI interaction fixture should fail")
    t.assert_true(_errors_contain(malformed_ai_result.errors, "AI interaction must be an object"), "non-object AI interaction error: %s" % malformed_ai_result.errors)

    var malformed_ai_response: Dictionary = scenario.duplicate(true)
    malformed_ai_response.ai_interaction.response = "invalid"
    var malformed_ai_response_result := _load_fixture(malformed_ai_response)
    t.assert_false(malformed_ai_response_result.ok, "non-object AI response fixture should fail")
    t.assert_true(_errors_contain(malformed_ai_response_result.errors, "AI response must be an object"), "non-object AI response error: %s" % malformed_ai_response_result.errors)

    var wrong_points: Dictionary = scenario.duplicate(true)
    wrong_points.scoring.criteria[0].configured_points = 11
    _assert_invalid(t, wrong_points, "Configured points mismatch for trace_before_change", "mismatched criterion points")

    var fractional_quick_key: Dictionary = scenario.duplicate(true)
    fractional_quick_key.stations[0].quick_key = 1.5
    var fractional_result := _load_fixture(fractional_quick_key)
    t.assert_false(fractional_result.ok, "fractional quick-key fixture should fail")
    t.assert_true(_errors_contain(fractional_result.errors, "stations[0].quick_key must be an integer"), "fractional quick-key error: %s" % fractional_result.errors)

func _assert_invalid(t: RefCounted, scenario: Dictionary, expected_error: String, message: String) -> void:
    var errors := ScenarioLoader.validate_scenario(scenario)
    t.assert_true(_errors_contain(errors, expected_error), "%s should fail with '%s', got %s" % [message, expected_error, errors])

func _errors_contain(errors: PackedStringArray, expected_error: String) -> bool:
    for error in errors:
        if error == expected_error:
            return true
    return false

func _load_fixture(scenario: Dictionary) -> Dictionary:
    var path := "user://task_1_fractional_quick_key.json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Fixture file could not be opened"])}
    file.store_string(JSON.stringify(scenario))
    file.close()
    return ScenarioLoader.load_file(path)
