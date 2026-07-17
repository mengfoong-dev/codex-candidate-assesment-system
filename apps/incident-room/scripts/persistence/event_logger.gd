class_name EventLogger
extends RefCounted

const EventSchemaScript = preload("res://scripts/domain/event_schema.gd")

var _session_id: String
var _scenario_id: String
var _scenario_version: String
var _base_directory: String
var _writer: Callable
var _next_sequence := 1
var _events: Array[Dictionary] = []
var _persistence_warning := ""
# Optional live sink: called with each accepted event so a listener (main.gd) can stream it to the
# backend as it happens. Set via set_on_append; unset in tests/offline -> logging stays local-only.
var _on_append := Callable()

func _init(
        session_id: String,
        scenario_id: String,
        scenario_version: String,
        base_directory: String = "user://vibeproof",
        writer: Callable = Callable()
    ) -> void:
    _session_id = session_id
    _scenario_id = scenario_id
    _scenario_version = scenario_version
    _base_directory = base_directory.rstrip("/")
    _writer = writer

## Register a listener invoked with every accepted event (post-validation), for live backend
## streaming. Kept as a setter, not an _init arg, so the injected logger_factory signature is stable.
func set_on_append(callback: Callable) -> void:
    _on_append = callback

func append(event_type: String, payload: Dictionary) -> Dictionary:
    var event: Dictionary = EventSchemaScript.build(
        _session_id,
        _next_sequence,
        event_type,
        Time.get_datetime_string_from_system(true, true),
        _scenario_id,
        _scenario_version,
        payload
    )
    var errors: PackedStringArray = EventSchemaScript.validate(event)
    if not errors.is_empty():
        return {"ok": false, "errors": errors}

    _events.append(event.duplicate(true))
    _next_sequence += 1
    # Stream to the backend (if wired) the moment the event is accepted — independent of disk write,
    # so grading sees the event even when local persistence fails.
    if _on_append.is_valid():
        _on_append.call(event.duplicate(true))
    var write_error := _append_line(_events_path(), JSON.stringify(event))
    if write_error != OK:
        _persistence_warning = "Session evidence is retained in memory but could not be saved to disk (error %d)." % write_error
        return {"ok": true, "event": event.duplicate(true), "saved": false}
    return {"ok": true, "event": event.duplicate(true), "saved": true}

func events() -> Array[Dictionary]:
    var copied_events: Array[Dictionary] = []
    for event in _events:
        copied_events.append(event.duplicate(true))
    return copied_events

func has_persistence_warning() -> bool:
    return not _persistence_warning.is_empty()

func persistence_warning() -> String:
    return _persistence_warning

func session_directory() -> String:
    return _base_directory.path_join(_session_id)

func _events_path() -> String:
    return session_directory().path_join("events.jsonl")

func _append_line(path: String, line: String) -> int:
    if _writer.is_valid():
        return int(_writer.call(path, line))

    var absolute_directory := ProjectSettings.globalize_path(session_directory())
    var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
    if directory_error != OK:
        return directory_error

    var file := FileAccess.open(path, FileAccess.READ_WRITE)
    if file == null:
        file = FileAccess.open(path, FileAccess.WRITE_READ)
    if file == null:
        return FileAccess.get_open_error()
    file.seek_end()
    file.store_line(line)
    return OK
