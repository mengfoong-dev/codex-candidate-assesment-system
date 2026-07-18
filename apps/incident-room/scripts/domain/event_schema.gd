class_name EventSchema
extends RefCounted

const SCHEMA_VERSION := "1.0.0"
const EVENT_TYPES: Array[String] = [
    "assessment_opened",
    "hypothesis_recorded",
    "evidence_viewed",
    "ai_prompt_submitted",
    "ai_response_received",
    "ai_suggestion_dispositioned",
    "hypothesis_revised",
    "test_executed",
    "decision_recorded",
    "final_submission",
    "station_visited",
    # Layer-2 review only: the candidate's raw prompt/question text. Not scored (the grader
    # drops these), captured so a reviewer can judge how they gathered info and used AI.
    "candidate_ai_prompt",
    "candidate_senior_question",
]
const REQUIRED_KEYS: Array[String] = [
    "schema_version",
    "session_id",
    "sequence",
    "event_type",
    "recorded_at_utc",
    "scenario_id",
    "scenario_version",
    "payload",
]
const FORBIDDEN_FIELDS: Array[String] = [
    "score",
    "points",
    "criteria",
    "pass",
    "rank",
    "capability",
    "recommendation",
]

static func build(
        session_id: String,
        sequence: int,
        event_type: String,
        recorded_at_utc: String,
        scenario_id: String,
        scenario_version: String,
        payload: Dictionary
    ) -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "session_id": session_id,
        "sequence": sequence,
        "event_type": event_type,
        "recorded_at_utc": recorded_at_utc,
        "scenario_id": scenario_id,
        "scenario_version": scenario_version,
        "payload": payload.duplicate(true),
    }

static func validate(event: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for key in REQUIRED_KEYS:
        if not event.has(key):
            errors.append("Event is missing required field: %s" % key)

    if str(event.get("schema_version", "")) != SCHEMA_VERSION:
        errors.append("Unsupported event schema version: %s" % event.get("schema_version", ""))
    _require_text(event, "session_id", errors)
    _require_text(event, "recorded_at_utc", errors)
    _require_text(event, "scenario_id", errors)
    _require_text(event, "scenario_version", errors)

    var sequence: Variant = event.get("sequence")
    if typeof(sequence) != TYPE_INT or int(sequence) < 1:
        errors.append("Event sequence must be at least 1")

    var event_type := str(event.get("event_type", ""))
    if not EVENT_TYPES.has(event_type):
        errors.append("Unknown event type: %s" % event_type)

    var payload: Variant = event.get("payload")
    if typeof(payload) != TYPE_DICTIONARY:
        errors.append("Event payload must be an object")
    else:
        _reject_forbidden_fields(payload, errors)
    return errors

static func _require_text(event: Dictionary, key: String, errors: PackedStringArray) -> void:
    if str(event.get(key, "")).strip_edges().is_empty():
        errors.append("Event field must not be blank: %s" % key)

static func _reject_forbidden_fields(value: Variant, errors: PackedStringArray) -> void:
    if typeof(value) == TYPE_DICTIONARY:
        var dictionary: Dictionary = value
        for key: Variant in dictionary.keys():
            var field_name := str(key)
            if FORBIDDEN_FIELDS.has(field_name):
                errors.append("Scoring field is forbidden: %s" % field_name)
            _reject_forbidden_fields(dictionary[key], errors)
    elif typeof(value) == TYPE_ARRAY:
        for item: Variant in value:
            _reject_forbidden_fields(item, errors)
