class_name CandidateSession
extends RefCounted

var _scenario: Dictionary
var _logger: RefCounted
var _session_id := ""
var _opened := false
var _completed := false
var _hypothesis_version := 0
var _initial_hypothesis: Dictionary = {}
var _current_hypothesis: Dictionary = {}
var _viewed_artifact_ids: Array[String] = []
var _ai_disposition_id := ""
var _verification_actions: Array[Dictionary] = []
var _final_submission: Dictionary = {}

func _init(scenario: Dictionary, logger: RefCounted) -> void:
    _scenario = scenario.duplicate(true)
    _logger = logger

func open_assessment(notice_confirmed: bool) -> Dictionary:
    if _opened:
        return _reject("Assessment is already open")
    if not notice_confirmed:
        return _reject("Assessment notice must be confirmed")
    var result: Dictionary = _logger.append("assessment_opened", {"notice_confirmed": true})
    if result.ok:
        _opened = true
        _session_id = result.event.session_id
    return result

func record_initial_hypothesis(hypothesis_id: String, confidence: int) -> Dictionary:
    var phase_error := _require_investigation_ready(false)
    if not phase_error.is_empty():
        return _reject(phase_error)
    if _hypothesis_version != 0:
        return _reject("Initial hypothesis is already recorded")
    if _find_by_id(_scenario.hypotheses, "hypothesis_id", hypothesis_id).is_empty():
        return _reject("Unknown hypothesis: %s" % hypothesis_id)
    if not _valid_confidence(confidence):
        return _reject("Confidence must be between 0 and 100")
    var hypothesis := {"hypothesis_id": hypothesis_id, "confidence": confidence, "version": 1}
    var result: Dictionary = _logger.append("hypothesis_recorded", hypothesis)
    if result.ok:
        _hypothesis_version = 1
        _initial_hypothesis = hypothesis.duplicate(true)
        _current_hypothesis = hypothesis.duplicate(true)
    return result

func view_evidence(artifact_id: String) -> Dictionary:
    var phase_error := _require_investigation_ready()
    if not phase_error.is_empty():
        return _reject(phase_error)
    var artifact := _find_by_id(_scenario.artifacts, "artifact_id", artifact_id)
    if artifact.is_empty():
        return _reject("Unknown artifact: %s" % artifact_id)
    var fact_ids: Array[String] = []
    for fact: Dictionary in artifact.facts:
        fact_ids.append(fact.fact_id)
    var result: Dictionary = _logger.append("evidence_viewed", {
        "artifact_id": artifact_id,
        "station_id": artifact.station_id,
        "evidence_type": artifact.evidence_type,
        "fact_ids": fact_ids,
    })
    if result.ok:
        _viewed_artifact_ids.append(artifact_id)
    return result

func record_ai_disposition(option_id: String) -> Dictionary:
    var phase_error := _require_investigation_ready()
    if not phase_error.is_empty():
        return _reject(phase_error)
    var option := _find_by_id(_scenario.ai_interaction.dispositions, "option_id", option_id)
    if option.is_empty():
        return _reject("Unknown AI disposition: %s" % option_id)
    var prompt: Dictionary = _scenario.ai_interaction.prompt
    var response: Dictionary = _scenario.ai_interaction.response
    var results: Array[Dictionary] = [
        _logger.append("ai_prompt_submitted", {"prompt_id": prompt.prompt_id, "referenced_context_ids": prompt.referenced_context_ids}),
        _logger.append("ai_response_received", {"response_id": response.response_id, "model_label": response.model_label, "status": response.status}),
        _logger.append("ai_suggestion_dispositioned", {"response_id": response.response_id, "option_id": option_id, "disposition": option.disposition, "verification_ids": option.verification_ids}),
    ]
    for result in results:
        if not result.ok:
            return result
    _ai_disposition_id = option_id
    return results.back()

func revise_hypothesis(hypothesis_id: String, confidence: int, trigger_fact_ids: Array) -> Dictionary:
    var phase_error := _require_investigation_ready()
    if not phase_error.is_empty():
        return _reject(phase_error)
    if _find_by_id(_scenario.hypotheses, "hypothesis_id", hypothesis_id).is_empty():
        return _reject("Unknown hypothesis: %s" % hypothesis_id)
    if not _valid_confidence(confidence):
        return _reject("Confidence must be between 0 and 100")
    var visible_facts := _visible_fact_ids()
    for fact_id: Variant in trigger_fact_ids:
        if not visible_facts.has(str(fact_id)):
            return _reject("Trigger fact was not viewed: %s" % fact_id)
    var next_version := _hypothesis_version + 1
    var payload := {
        "previous_hypothesis_id": _current_hypothesis.hypothesis_id,
        "hypothesis_id": hypothesis_id,
        "confidence": confidence,
        "version": next_version,
        "trigger_fact_ids": trigger_fact_ids.duplicate(),
    }
    var result: Dictionary = _logger.append("hypothesis_revised", payload)
    if result.ok:
        _hypothesis_version = next_version
        _current_hypothesis = {"hypothesis_id": hypothesis_id, "confidence": confidence, "version": next_version}
    return result

func record_verification(test_id: String, remediation_id: String) -> Dictionary:
    var phase_error := _require_investigation_ready()
    if not phase_error.is_empty():
        return _reject(phase_error)
    var test := _find_by_id(_scenario.tests, "test_id", test_id)
    if test.is_empty():
        return _reject("Unknown test: %s" % test_id)
    if _find_by_id(_scenario.submission_options.remediations, "option_id", remediation_id).is_empty():
        return _reject("Unknown remediation: %s" % remediation_id)
    var displayed_result: Dictionary = test.results_by_remediation.get(remediation_id, {})
    var payload := {
        "test_id": test_id,
        "remediation_id": remediation_id,
        "expected_result": test.expected_result,
        "displayed_result": displayed_result.duplicate(true),
    }
    var result: Dictionary = _logger.append("test_executed", payload)
    if result.ok:
        _verification_actions.append(payload.duplicate(true))
    return result

func submit_final(submission: Dictionary) -> Dictionary:
    var phase_error := _require_investigation_ready()
    if not phase_error.is_empty():
        return _reject(phase_error)
    var validation_error := _validate_submission(submission)
    if not validation_error.is_empty():
        return _reject(validation_error)
    var decision_result: Dictionary = _logger.append("decision_recorded", {
        "root_cause_id": submission.root_cause_id,
        "remediation_id": submission.remediation_id,
        "risk_ids": submission.get("risk_ids", []).duplicate(),
        "assumption_ids": submission.get("assumption_ids", []).duplicate(),
        "rollback_id": submission.rollback_id,
        "rationale": submission.get("rationale", ""),
    })
    if not decision_result.ok:
        return decision_result
    var final_result: Dictionary = _logger.append("final_submission", submission.duplicate(true))
    if final_result.ok:
        _final_submission = submission.duplicate(true)
        _completed = true
    return final_result

func snapshot() -> Dictionary:
    return {
        "session_id": _session_id,
        "scenario_id": _scenario.scenario_id,
        "scenario_version": _scenario.scenario_version,
        "opened": _opened,
        "completed": _completed,
        "hypothesis_version": _hypothesis_version,
        "initial_hypothesis": _initial_hypothesis.duplicate(true),
        "current_hypothesis": _current_hypothesis.duplicate(true),
        "viewed_artifact_ids": _viewed_artifact_ids.duplicate(),
        "ai_disposition_id": _ai_disposition_id,
        "verification_actions": _verification_actions.duplicate(true),
        "final_submission": _final_submission.duplicate(true),
    }

func ordered_events() -> Array[Dictionary]:
    return _logger.events()

func _require_investigation_ready(require_hypothesis: bool = true) -> String:
    if not _opened:
        return "Assessment is not open"
    if _completed:
        return "Assessment is already complete"
    if require_hypothesis and _hypothesis_version == 0:
        return "Initial hypothesis is required"
    return ""

func _validate_submission(submission: Dictionary) -> String:
    var required := ["root_cause_id", "remediation_id", "validation_test_ids", "rollback_id", "final_confidence"]
    for key: String in required:
        if not submission.has(key):
            return "Submission is missing required field: %s" % key
    if _find_by_id(_scenario.submission_options.root_causes, "option_id", str(submission.root_cause_id)).is_empty():
        return "Unknown root cause: %s" % submission.root_cause_id
    if _find_by_id(_scenario.submission_options.remediations, "option_id", str(submission.remediation_id)).is_empty():
        return "Unknown remediation: %s" % submission.remediation_id
    if _find_by_id(_scenario.submission_options.rollbacks, "option_id", str(submission.rollback_id)).is_empty():
        return "Unknown rollback: %s" % submission.rollback_id
    if not _valid_confidence(int(submission.final_confidence)):
        return "Confidence must be between 0 and 100"
    var validation_ids: Array = submission.validation_test_ids
    if validation_ids.is_empty():
        return "At least one validation test is required"
    for test_id: Variant in validation_ids:
        if _find_by_id(_scenario.tests, "test_id", str(test_id)).is_empty():
            return "Unknown test: %s" % test_id
        if not _verification_recorded(str(test_id), str(submission.remediation_id)):
            return "Validation test was not executed: %s" % test_id
    for artifact_id: Variant in submission.get("evidence_ids", []):
        if not _viewed_artifact_ids.has(str(artifact_id)):
            return "Evidence was not viewed: %s" % artifact_id
    return ""

func _verification_recorded(test_id: String, remediation_id: String) -> bool:
    for action in _verification_actions:
        if action.test_id == test_id and action.remediation_id == remediation_id:
            return true
    return false

func _visible_fact_ids() -> Array[String]:
    var fact_ids: Array[String] = []
    for artifact_id in _viewed_artifact_ids:
        var artifact := _find_by_id(_scenario.artifacts, "artifact_id", artifact_id)
        for fact: Dictionary in artifact.get("facts", []):
            if not fact_ids.has(fact.fact_id):
                fact_ids.append(fact.fact_id)
    return fact_ids

func _find_by_id(items: Variant, id_field: String, requested_id: String) -> Dictionary:
    if typeof(items) != TYPE_ARRAY:
        return {}
    for item: Variant in items:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(id_field, "")) == requested_id:
            return item
    return {}

func _valid_confidence(confidence: int) -> bool:
    return confidence >= 0 and confidence <= 100

func _reject(message: String) -> Dictionary:
    return {"ok": false, "errors": PackedStringArray([message])}
