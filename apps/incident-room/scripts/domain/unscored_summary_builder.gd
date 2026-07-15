class_name UnscoredSummaryBuilder
extends RefCounted

const SUMMARY_LABEL := "Unscored prototype summary"

static func build(
        scenario: Dictionary,
        snapshot: Dictionary,
        events: Array[Dictionary],
        saved_to_disk: bool,
        persistence_warning: String
    ) -> Dictionary:
    return {
        "label": SUMMARY_LABEL,
        "session_id": str(snapshot.get("session_id", "")),
        "scenario_id": str(snapshot.get("scenario_id", scenario.get("scenario_id", ""))),
        "scenario_version": str(snapshot.get("scenario_version", scenario.get("scenario_version", ""))),
        "completed": bool(snapshot.get("completed", false)),
        "saved_to_disk": saved_to_disk,
        "persistence_warning": persistence_warning,
        "initial_hypothesis": _map_hypothesis(scenario, snapshot.get("initial_hypothesis", {})),
        "final_hypothesis": _map_hypothesis(scenario, snapshot.get("current_hypothesis", {})),
        "evidence_timeline": _build_evidence_timeline(scenario, events),
        "ai_disposition": _map_ai_disposition(scenario, str(snapshot.get("ai_disposition_id", ""))),
        "verification_actions": _map_verification_actions(scenario, snapshot.get("verification_actions", [])),
        "final_submission": _map_final_submission(scenario, snapshot.get("final_submission", {})),
        "notices": scenario.get("notices", {}).duplicate(true),
    }

static func _map_hypothesis(scenario: Dictionary, hypothesis: Variant) -> Dictionary:
    if typeof(hypothesis) != TYPE_DICTIONARY or hypothesis.is_empty():
        return {}
    var hypothesis_id := str(hypothesis.get("hypothesis_id", ""))
    var option := _find_by_id(scenario.get("hypotheses", []), "hypothesis_id", hypothesis_id)
    return {
        "hypothesis_id": hypothesis_id,
        "label": str(option.get("label", hypothesis_id)),
        "confidence": int(hypothesis.get("confidence", 0)),
        "version": int(hypothesis.get("version", 0)),
    }

static func _build_evidence_timeline(scenario: Dictionary, events: Array[Dictionary]) -> Array[Dictionary]:
    var timeline: Array[Dictionary] = []
    for event: Dictionary in events:
        if str(event.get("event_type", "")) != "evidence_viewed":
            continue
        var payload: Dictionary = event.get("payload", {})
        var artifact_id := str(payload.get("artifact_id", ""))
        var artifact := _find_by_id(scenario.get("artifacts", []), "artifact_id", artifact_id)
        timeline.append({
            "sequence": int(event.get("sequence", 0)),
            "recorded_at_utc": str(event.get("recorded_at_utc", "")),
            "artifact_id": artifact_id,
            "title": str(artifact.get("title", artifact_id)),
            "evidence_type": str(artifact.get("evidence_type", payload.get("evidence_type", ""))),
        })
    return timeline

static func _map_ai_disposition(scenario: Dictionary, option_id: String) -> Dictionary:
    if option_id.is_empty():
        return {}
    var interaction: Dictionary = scenario.get("ai_interaction", {})
    var option := _find_by_id(interaction.get("dispositions", []), "option_id", option_id)
    return {
        "option_id": option_id,
        "disposition": str(option.get("disposition", "")),
        "verification_ids": option.get("verification_ids", []).duplicate(),
    }

static func _map_verification_actions(scenario: Dictionary, actions: Variant) -> Array[Dictionary]:
    var mapped: Array[Dictionary] = []
    if typeof(actions) != TYPE_ARRAY:
        return mapped
    var options: Dictionary = scenario.get("submission_options", {})
    for action: Variant in actions:
        if typeof(action) != TYPE_DICTIONARY:
            continue
        mapped.append({
            "test": _map_test(scenario, str(action.get("test_id", ""))),
            "remediation": _map_option(options.get("remediations", []), str(action.get("remediation_id", ""))),
            "expected_result": str(action.get("expected_result", "")),
            "displayed_result": action.get("displayed_result", {}).duplicate(true),
        })
    return mapped

static func _map_final_submission(scenario: Dictionary, submission: Variant) -> Dictionary:
    if typeof(submission) != TYPE_DICTIONARY or submission.is_empty():
        return {}
    var options: Dictionary = scenario.get("submission_options", {})
    var mapped := {
        "root_cause": _map_option(options.get("root_causes", []), str(submission.get("root_cause_id", ""))),
        "evidence": _map_artifact_ids(scenario, submission.get("evidence_ids", [])),
        "remediation": _map_option(options.get("remediations", []), str(submission.get("remediation_id", ""))),
        "risks": _map_option_ids(options.get("risks", []), submission.get("risk_ids", [])),
        "assumptions": _map_option_ids(options.get("assumptions", []), submission.get("assumption_ids", [])),
        "validation_tests": _map_test_ids(scenario, submission.get("validation_test_ids", [])),
        "rollback": _map_option(options.get("rollbacks", []), str(submission.get("rollback_id", ""))),
        "final_confidence": int(submission.get("final_confidence", 0)),
        "rationale": str(submission.get("rationale", "")),
    }
    if submission.has("expected_impact_id"):
        mapped["expected_impact"] = _map_option(
            options.get("expected_impacts", []),
            str(submission.expected_impact_id)
        )
    return mapped

static func _map_artifact_ids(scenario: Dictionary, ids: Variant) -> Array[Dictionary]:
    var mapped: Array[Dictionary] = []
    if typeof(ids) != TYPE_ARRAY:
        return mapped
    for artifact_id: Variant in ids:
        var requested_id := str(artifact_id)
        var artifact := _find_by_id(scenario.get("artifacts", []), "artifact_id", requested_id)
        mapped.append({
            "artifact_id": requested_id,
            "title": str(artifact.get("title", requested_id)),
            "evidence_type": str(artifact.get("evidence_type", "")),
        })
    return mapped

static func _map_option_ids(items: Variant, ids: Variant) -> Array[Dictionary]:
    var mapped: Array[Dictionary] = []
    if typeof(ids) != TYPE_ARRAY:
        return mapped
    for option_id: Variant in ids:
        mapped.append(_map_option(items, str(option_id)))
    return mapped

static func _map_test_ids(scenario: Dictionary, ids: Variant) -> Array[Dictionary]:
    var mapped: Array[Dictionary] = []
    if typeof(ids) != TYPE_ARRAY:
        return mapped
    for test_id: Variant in ids:
        mapped.append(_map_test(scenario, str(test_id)))
    return mapped

static func _map_test(scenario: Dictionary, test_id: String) -> Dictionary:
    var test := _find_by_id(scenario.get("tests", []), "test_id", test_id)
    return {
        "test_id": test_id,
        "title": str(test.get("title", test_id)),
    }

static func _map_option(items: Variant, option_id: String) -> Dictionary:
    var option := _find_by_id(items, "option_id", option_id)
    return {
        "option_id": option_id,
        "label": str(option.get("label", option_id)),
    }

static func _find_by_id(items: Variant, id_field: String, requested_id: String) -> Dictionary:
    if typeof(items) != TYPE_ARRAY:
        return {}
    for item: Variant in items:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(id_field, "")) == requested_id:
            return item
    return {}
