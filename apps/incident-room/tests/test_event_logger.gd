extends RefCounted

const EventLoggerScript = preload("res://scripts/persistence/event_logger.gd")

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var session_id := "test-session-%d" % Time.get_ticks_usec()
    var logger = EventLoggerScript.new(
        session_id,
        "homepage_latency",
        "1.0.0",
        "user://test-vibeproof",
        Callable()
    )

    var first: Dictionary = logger.append("assessment_opened", {"notice_confirmed": true})
    var second: Dictionary = logger.append("hypothesis_recorded", {"hypothesis_id": "redis_degradation"})
    t.assert_true(first.ok and first.saved, "first event should persist")
    t.assert_true(second.ok and second.saved, "second event should persist")
    t.assert_equal(first.event.sequence, 1, "first sequence")
    t.assert_equal(second.event.sequence, 2, "second sequence")
    t.assert_equal(logger.events().size(), 2, "in-memory event count")

    var event_path: String = logger.session_directory().path_join("events.jsonl")
    var lines := FileAccess.get_file_as_string(event_path).strip_edges().split("\n", false)
    t.assert_equal(lines.size(), 2, "JSONL line count")
    for line_index in lines.size():
        var parsed: Variant = JSON.parse_string(lines[line_index])
        t.assert_true(typeof(parsed) == TYPE_DICTIONARY, "JSONL line %d parses" % line_index)
        if typeof(parsed) == TYPE_DICTIONARY:
            t.assert_equal(parsed.sequence, line_index + 1, "JSONL sequence %d" % line_index)

    var fallback_logger = EventLoggerScript.new(
        "fallback-session",
        "homepage_latency",
        "1.0.0",
        "user://test-vibeproof",
        Callable(self, "_fail_write")
    )
    var fallback_result: Dictionary = fallback_logger.append(
        "assessment_opened",
        {"notice_confirmed": true}
    )
    t.assert_true(fallback_result.ok, "fallback append should remain accepted")
    t.assert_false(fallback_result.saved, "fallback append should report unsaved")
    t.assert_equal(fallback_logger.events().size(), 1, "fallback event remains in memory")
    t.assert_true(fallback_logger.has_persistence_warning(), "fallback warning should be visible")

    return t.failures

func _fail_write(_path: String, _line: String) -> Error:
    return ERR_CANT_CREATE
