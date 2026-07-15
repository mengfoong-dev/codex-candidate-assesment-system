extends RefCounted

const EventSchemaScript = preload("res://scripts/domain/event_schema.gd")
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

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var event: Dictionary = EventSchemaScript.build(
        "session-1",
        1,
        "assessment_opened",
        "2026-07-15T13:00:00Z",
        "homepage_latency",
        "1.0.0",
        {"notice_confirmed": true}
    )

    t.assert_has_keys(event, REQUIRED_KEYS, "event envelope")
    t.assert_equal(EventSchemaScript.validate(event), PackedStringArray(), "valid event")

    var scored_event := event.duplicate(true)
    scored_event.payload.result = {"score": 10}
    t.assert_true(
        EventSchemaScript.validate(scored_event).has("Scoring field is forbidden: score"),
        "nested score should be rejected"
    )

    var invalid_sequence := event.duplicate(true)
    invalid_sequence.sequence = 0
    t.assert_true(
        EventSchemaScript.validate(invalid_sequence).has("Event sequence must be at least 1"),
        "invalid sequence should be rejected"
    )

    var unknown_type := event.duplicate(true)
    unknown_type.event_type = "candidate_scored"
    t.assert_true(
        EventSchemaScript.validate(unknown_type).has("Unknown event type: candidate_scored"),
        "unknown event type should be rejected"
    )

    return t.failures
