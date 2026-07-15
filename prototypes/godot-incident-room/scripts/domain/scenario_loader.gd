class_name ScenarioLoader
extends RefCounted

const REQUIRED_KEYS: Array[String] = [
    "schema_version", "scenario_id", "scenario_version", "title", "role",
    "brief", "stations", "artifacts", "hypotheses", "ai_interaction",
    "tests", "submission_options", "scoring", "notices"
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

static func load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Scenario file not found: %s" % path])}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Scenario file could not be opened: %s" % path])}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"ok": false, "scenario": {}, "errors": PackedStringArray(["Scenario root must be a JSON object"])}
    var scenario: Dictionary = parsed
    var errors := _normalize_integer_fields(scenario)
    errors.append_array(validate_scenario(scenario))
    return {"ok": errors.is_empty(), "scenario": scenario if errors.is_empty() else {}, "errors": errors}

static func validate_scenario(scenario: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for key in REQUIRED_KEYS:
        if not scenario.has(key):
            errors.append("Missing scenario key: %s" % key)
    if scenario.get("scenario_id", "") != "homepage_latency":
        errors.append("Unsupported scenario id")
    if scenario.get("scenario_version", "") != "1.0.0":
        errors.append("Unsupported scenario version")
    if scenario.get("schema_version", "") != "1.0.0":
        errors.append("Unsupported scenario schema version")
    if typeof(scenario.get("artifacts", null)) != TYPE_ARRAY or scenario.get("artifacts", []).size() != 4:
        errors.append("Scenario must define exactly four artifacts")
    errors.append_array(_validate_normalized_integer_fields(scenario))
    errors.append_array(_validate_unique_ids_and_references(scenario))
    return errors

static func _normalize_integer_fields(scenario: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var stations_value: Variant = scenario.get("stations", [])
    if typeof(stations_value) == TYPE_ARRAY:
        var stations: Array = stations_value
        for index in range(stations.size()):
            var station_value: Variant = stations[index]
            if typeof(station_value) == TYPE_DICTIONARY:
                var station: Dictionary = station_value
                _normalize_integer_field(station, "quick_key", "stations[%d].quick_key" % index, errors)

    var ai_value: Variant = scenario.get("ai_interaction", {})
    if typeof(ai_value) == TYPE_DICTIONARY:
        var ai: Dictionary = ai_value
        var response_value: Variant = ai.get("response", {})
        if typeof(response_value) == TYPE_DICTIONARY:
            var response: Dictionary = response_value
            _normalize_integer_field(response, "latency_ms", "ai_interaction.response.latency_ms", errors)

    var scoring_value: Variant = scenario.get("scoring", {})
    if typeof(scoring_value) == TYPE_DICTIONARY:
        var scoring: Dictionary = scoring_value
        var criteria_value: Variant = scoring.get("criteria", [])
        if typeof(criteria_value) == TYPE_ARRAY:
            var criteria: Array = criteria_value
            for index in range(criteria.size()):
                var criterion_value: Variant = criteria[index]
                if typeof(criterion_value) == TYPE_DICTIONARY:
                    var criterion: Dictionary = criterion_value
                    _normalize_integer_field(criterion, "configured_points", "scoring.criteria[%d].configured_points" % index, errors)
    return errors

static func _normalize_integer_field(container: Dictionary, field: String, path: String, errors: PackedStringArray) -> void:
    if not container.has(field):
        errors.append("%s must be an integer" % path)
        return
    var value: Variant = container[field]
    if typeof(value) == TYPE_INT:
        return
    if typeof(value) != TYPE_FLOAT or not is_finite(value) or value != floor(value):
        errors.append("%s must be an integer" % path)
        return
    container[field] = int(value)

static func _validate_normalized_integer_fields(scenario: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var quick_keys: Array[int] = []
    var stations_value: Variant = scenario.get("stations", [])
    if typeof(stations_value) == TYPE_ARRAY:
        for station_value in stations_value:
            if typeof(station_value) != TYPE_DICTIONARY:
                continue
            var station: Dictionary = station_value
            var quick_key: Variant = station.get("quick_key", null)
            if typeof(quick_key) != TYPE_INT:
                errors.append("Station quick keys must be integers")
            else:
                quick_keys.append(quick_key)
    if quick_keys.size() != 3 or not quick_keys.has(1) or not quick_keys.has(2) or not quick_keys.has(3):
        errors.append("Station quick keys must be exactly 1, 2, and 3")

    var ai_value: Variant = scenario.get("ai_interaction", {})
    if typeof(ai_value) != TYPE_DICTIONARY:
        errors.append("AI interaction must be an object")
    else:
        var ai: Dictionary = ai_value
        var response_value: Variant = ai.get("response", {})
        if typeof(response_value) != TYPE_DICTIONARY:
            errors.append("AI response must be an object")
        else:
            var response: Dictionary = response_value
            var latency: Variant = response.get("latency_ms", null)
            if typeof(latency) != TYPE_INT:
                errors.append("AI response latency must be an integer")
            elif latency < 0:
                errors.append("AI response latency must be non-negative")

    var configured_criteria: Dictionary = {}
    var scoring_value: Variant = scenario.get("scoring", {})
    if typeof(scoring_value) == TYPE_DICTIONARY:
        var scoring: Dictionary = scoring_value
        var criteria_value: Variant = scoring.get("criteria", [])
        if typeof(criteria_value) == TYPE_ARRAY:
            for criterion_value in criteria_value:
                if typeof(criterion_value) != TYPE_DICTIONARY:
                    continue
                var criterion: Dictionary = criterion_value
                var criterion_id := str(criterion.get("criterion_id", ""))
                if not EXPECTED_CRITERION_POINTS.has(criterion_id):
                    errors.append("Unsupported scoring criterion: %s" % criterion_id)
                    continue
                configured_criteria[criterion_id] = true
                var configured_points: Variant = criterion.get("configured_points", null)
                if typeof(configured_points) != TYPE_INT:
                    errors.append("Configured points must be an integer for %s" % criterion_id)
                elif configured_points != EXPECTED_CRITERION_POINTS[criterion_id]:
                    errors.append("Configured points mismatch for %s" % criterion_id)
    for criterion_id in EXPECTED_CRITERION_POINTS:
        if not configured_criteria.has(criterion_id):
            errors.append("Missing scoring criterion: %s" % criterion_id)
    return errors

static func _validate_unique_ids_and_references(scenario: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var station_ids := _collect_unique_ids(scenario.get("stations", []), "station_id", "station", errors)
    var hypothesis_ids := _collect_unique_ids(scenario.get("hypotheses", []), "hypothesis_id", "hypothesis", errors)
    var artifact_ids := _collect_unique_ids(scenario.get("artifacts", []), "artifact_id", "artifact", errors)
    var test_ids := _collect_unique_ids(scenario.get("tests", []), "test_id", "test", errors)
    var fact_ids: Dictionary = {}
    var artifacts_value: Variant = scenario.get("artifacts", [])
    if typeof(artifacts_value) == TYPE_ARRAY:
        for artifact_value in artifacts_value:
            if typeof(artifact_value) != TYPE_DICTIONARY:
                errors.append("Artifact entries must be objects")
                continue
            var artifact: Dictionary = artifact_value
            if not station_ids.has(str(artifact.get("station_id", ""))):
                errors.append("Artifact references unknown station: %s" % artifact.get("station_id", ""))
            if not ["metrics", "logs", "trace", "source_code"].has(artifact.get("evidence_type", "")):
                errors.append("Artifact has unsupported evidence type: %s" % artifact.get("evidence_type", ""))
            var local_fact_ids := _collect_unique_ids(artifact.get("facts", []), "fact_id", "fact", errors)
            for fact_id in local_fact_ids:
                if fact_ids.has(fact_id):
                    errors.append("Duplicate fact id: %s" % fact_id)
                fact_ids[fact_id] = true

    var ai_value: Variant = scenario.get("ai_interaction", {})
    var ai: Dictionary = ai_value if typeof(ai_value) == TYPE_DICTIONARY else {}
    var prompt_value: Variant = ai.get("prompt", {})
    var prompt: Dictionary = prompt_value if typeof(prompt_value) == TYPE_DICTIONARY else {}
    var referenced_context_ids: Variant = prompt.get("referenced_context_ids", [])
    if typeof(referenced_context_ids) == TYPE_ARRAY:
        for artifact_id in referenced_context_ids:
            if not artifact_ids.has(artifact_id):
                errors.append("AI prompt references unknown artifact: %s" % artifact_id)
    _collect_unique_ids(ai.get("dispositions", []), "option_id", "AI disposition", errors)

    var options_value: Variant = scenario.get("submission_options", {})
    var options: Dictionary = options_value if typeof(options_value) == TYPE_DICTIONARY else {}
    var remediation_ids := _collect_unique_ids(options.get("remediations", []), "option_id", "remediation", errors)
    var root_causes_value: Variant = options.get("root_causes", [])
    if typeof(root_causes_value) == TYPE_ARRAY:
        for root_cause in root_causes_value:
            if typeof(root_cause) == TYPE_DICTIONARY and not hypothesis_ids.has(str(root_cause.get("option_id", ""))):
                errors.append("Root cause has no matching hypothesis: %s" % root_cause.get("option_id", ""))
    for group in ["root_causes", "expected_impacts", "risks", "assumptions", "rollbacks"]:
        _collect_unique_ids(options.get(group, []), "option_id", group, errors)
    var required_tests: Variant = options.get("required_validation_test_ids", [])
    if typeof(required_tests) == TYPE_ARRAY:
        for test_id in required_tests:
            if not test_ids.has(test_id):
                errors.append("Required validation references unknown test: %s" % test_id)

    var tests_value: Variant = scenario.get("tests", [])
    if typeof(tests_value) == TYPE_ARRAY:
        for test_value in tests_value:
            if typeof(test_value) != TYPE_DICTIONARY:
                continue
            var test: Dictionary = test_value
            var results_value: Variant = test.get("results_by_remediation", {})
            if typeof(results_value) != TYPE_DICTIONARY:
                continue
            for remediation_id in results_value:
                if not remediation_ids.has(remediation_id):
                    errors.append("Test result references unknown remediation: %s" % remediation_id)

    var scoring_value: Variant = scenario.get("scoring", {})
    var scoring: Dictionary = scoring_value if typeof(scoring_value) == TYPE_DICTIONARY else {}
    _collect_unique_ids(scoring.get("criteria", []), "criterion_id", "criterion", errors)
    return errors

static func _collect_unique_ids(items: Variant, id_field: String, label: String, errors: PackedStringArray) -> Dictionary:
    var ids: Dictionary = {}
    if typeof(items) != TYPE_ARRAY:
        errors.append("%s collection must be an array" % label.capitalize())
        return ids
    for item_value in items:
        if typeof(item_value) != TYPE_DICTIONARY:
            errors.append("%s entries must be objects" % label.capitalize())
            continue
        var item: Dictionary = item_value
        var item_id := str(item.get(id_field, ""))
        if item_id.is_empty():
            errors.append("%s is missing %s" % [label.capitalize(), id_field])
        elif ids.has(item_id):
            errors.append("Duplicate %s id: %s" % [label, item_id])
        else:
            ids[item_id] = true
    return ids
