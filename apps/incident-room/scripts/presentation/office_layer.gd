class_name OfficeLayer
extends Control

## Overlay for the walkable 3D office: a bottom interaction hint, a chat panel for the
## senior NPC (calls the senior-proxy for a live reply, with an offline fallback), and a
## read panel for the physical evidence stations. Emits intents; the coordinator owns the
## domain session.

signal evidence_view_requested(artifact_id: String)
signal modal_changed(open: bool)
signal view_toggle_requested
## Emitted with each question the candidate asks Sam — logged for Layer-2 review of gathering.
signal senior_question_asked(text: String)

## Where the senior's live voice comes from. Overridable per build/deploy.
@export var senior_proxy_url := "http://localhost:8080/api/senior/chat"
## Where Sam's reply is synthesized to speech (ElevenLabs via the backend; key stays server-side).
@export var tts_url := "https://vibeproof-backend-production.up.railway.app/api/tts"

const INK := Color(0.13, 0.17, 0.31, 1)
const MUTED := Color(0.4, 0.38, 0.44, 1)
const CREAM := Color(0.96, 0.94, 0.9, 1)
const CARD := Color(0.99, 0.97, 0.93, 1)
const SENIOR := Color(0.66, 0.42, 0.94, 1)

var _scenario: Dictionary = {}
var _snapshot: Dictionary = {}

var _hint: Label
var _scrim: Panel
var _modal: PanelContainer
var _title: Label
var _body: VBoxContainer
var _http: HTTPRequest
var _tts_http: HTTPRequest
var _tts_player: AudioStreamPlayer
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_send: Button
var _history: Array = []
var _sending := false

func _ready() -> void:
    # Let clicks fall through to the 3D game for click-to-walk; the modal scrim below
    # re-captures them while a panel is open.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_hint()
    _build_view_toggle()
    _build_modal()
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_senior_response)
    _tts_http = HTTPRequest.new()
    add_child(_tts_http)
    _tts_http.request_completed.connect(_on_tts_done)
    _tts_player = AudioStreamPlayer.new()
    add_child(_tts_player)
    _close()

func _build_view_toggle() -> void:
    var button := Button.new()
    button.text = "👁 View"
    button.focus_mode = Control.FOCUS_ALL
    button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    button.offset_left = -128
    button.offset_top = 16
    button.offset_right = -16
    button.offset_bottom = 52
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.12, 0.24, 0.92)
    style.set_corner_radius_all(9)
    style.set_content_margin_all(8)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", style)
    button.add_theme_stylebox_override("pressed", style)
    button.add_theme_color_override("font_color", CREAM)
    button.pressed.connect(func() -> void: view_toggle_requested.emit())
    add_child(button)

func configure(scenario: Dictionary) -> void:
    _scenario = scenario

func set_snapshot(snapshot: Dictionary) -> void:
    _snapshot = snapshot

func show_hint(text: String) -> void:
    _hint.text = text
    _hint.visible = not text.is_empty()

func is_modal_open() -> bool:
    return _scrim.visible

func close() -> void:
    _close()

# --- Senior chat -------------------------------------------------------------

func open_senior() -> void:
    _title.text = "☕  Sam — senior on-call engineer"
    _clear(_body)
    _history.clear()
    var log := RichTextLabel.new()
    log.bbcode_enabled = true
    log.fit_content = true
    log.scroll_active = true
    log.custom_minimum_size = Vector2(0, 300)
    log.add_theme_color_override("default_color", INK)
    _body.add_child(log)
    _chat_log = log
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    _body.add_child(row)
    var input := LineEdit.new()
    input.placeholder_text = "Ask Sam to clarify the task…"
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input.focus_mode = Control.FOCUS_ALL
    row.add_child(input)
    _chat_input = input
    var send := _button("Send")
    row.add_child(send)
    _chat_send = send
    _body.add_child(_close_button())
    input.text_submitted.connect(func(_t: String) -> void: _send())
    send.pressed.connect(_send)
    _say("Sam", "Morning! VibeTube's watch page p95 jumped from 180ms to 850ms right after the last release. Ask me anything, then hop on your laptop when you're ready.", SENIOR)
    _open()
    input.grab_focus.call_deferred()

func _send() -> void:
    if _sending or _chat_input == null:
        return
    var text := _chat_input.text.strip_edges()
    if text.is_empty():
        return
    _chat_input.text = ""
    _chat_input.grab_focus.call_deferred()  # Enter submits but shouldn't drop the cursor — keep typing
    senior_question_asked.emit(text)
    _say("You", text, INK)
    _history.append({"role": "user", "content": text})
    _sending = true
    _chat_send.disabled = true
    _say("Sam", "…", MUTED)
    var payload := {
        "messages": _history,
        "task": str(_scenario.get("brief", "")),
    }
    var headers := PackedStringArray(["Content-Type: application/json"])
    var err := _http.request(senior_proxy_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        _finish_reply(_fallback())

func _on_senior_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if not _sending:
        return
    var reply := ""
    if code == 200:
        var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
        if parsed is Dictionary:
            reply = str(parsed.get("reply", ""))
    _finish_reply(reply if not reply.is_empty() else _fallback())

func _finish_reply(reply: String) -> void:
    # Replace the trailing "…" placeholder with the real answer.
    _history.append({"role": "assistant", "content": reply})
    _sending = false
    if _chat_send != null:
        _chat_send.disabled = false
    if _chat_log != null:
        # Drop the trailing "Sam …" typing placeholder (split drops the empty tail line).
        var lines := _chat_log.text.split("\n", false)
        if lines.size() > 0 and lines[lines.size() - 1].contains("…"):
            lines.remove_at(lines.size() - 1)
        _chat_log.text = "\n".join(lines) + ("\n" if lines.size() > 0 else "")
    _say("Sam", reply, SENIOR)
    _speak(reply)
    if _chat_input != null:
        _chat_input.grab_focus.call_deferred()  # keep the cursor in the box so you can just keep talking

## Speak Sam's reply aloud via the backend TTS proxy. Best-effort: a 204/empty/error response just
## stays silent, so the text dialogue never waits on (or breaks over) the voice call.
func _speak(text: String) -> void:
    if _tts_http == null or text.strip_edges().is_empty():
        return
    _tts_http.cancel_request()  # a new reply supersedes any voice still being fetched
    var headers := PackedStringArray(["Content-Type: application/json"])
    _tts_http.request(tts_url, headers, HTTPClient.METHOD_POST, JSON.stringify({"text": text}))

func _on_tts_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if code != 200 or body.is_empty():
        return  # not configured / failed -> silence
    var stream := AudioStreamMP3.new()
    stream.data = body
    _tts_player.stream = stream
    _tts_player.play()

func _fallback() -> String:
    return "I can't get to my terminal this second — start with the request trace at your desk and see where the time actually goes."

# --- Station evidence read ---------------------------------------------------

func open_station(station_id: String) -> void:
    var station := _lookup(_scenario.get("stations", []), "station_id", station_id)
    _title.text = "🖥  %s" % str(station.get("title", station_id))
    _clear(_body)
    var viewed: Array = _snapshot.get("viewed_artifact_ids", [])
    var detail := RichTextLabel.new()
    detail.bbcode_enabled = true
    detail.fit_content = true
    detail.custom_minimum_size = Vector2(0, 180)
    detail.add_theme_color_override("default_color", INK)
    detail.text = "Pick an item to read it. Reading here records it in your session, same as the laptop's Evidence tab."
    for artifact: Dictionary in _scenario.get("artifacts", []):
        if str(artifact.get("station_id", "")) != station_id:
            continue
        var artifact_id := str(artifact.get("artifact_id", ""))
        var seen: bool = viewed.has(artifact_id)
        var button := _button("%s%s" % [artifact.get("title", artifact_id), "   ✓" if seen else ""])
        button.pressed.connect(func() -> void:
            evidence_view_requested.emit(artifact_id)
            _render_artifact(detail, artifact))
        _body.add_child(button)
    _body.add_child(detail)
    _body.add_child(_close_button())
    _open()

func _render_artifact(target: RichTextLabel, artifact: Dictionary) -> void:
    var lines := PackedStringArray(["[b]%s[/b]" % str(artifact.get("title", ""))])
    for line: Variant in artifact.get("content", []):
        lines.append("• %s" % str(line))
    target.text = "\n".join(lines)

# --- Shared UI ---------------------------------------------------------------

func _say(speaker: String, text: String, color: Color) -> void:
    if _chat_log == null:
        return
    var hex := color.to_html(false)
    _chat_log.text += "[color=#%s][b]%s[/b][/color]  %s\n" % [hex, speaker, text]

func _build_hint() -> void:
    var wrap := CenterContainer.new()
    wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    wrap.offset_top = -70
    wrap.offset_bottom = -22
    wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(wrap)
    var pill := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.12, 0.24, 0.92)
    style.set_corner_radius_all(10)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    pill.add_theme_stylebox_override("panel", style)
    wrap.add_child(pill)
    _hint = Label.new()
    _hint.add_theme_color_override("font_color", CREAM)
    _hint.add_theme_font_size_override("font_size", 16)
    pill.add_child(_hint)

func _build_modal() -> void:
    _scrim = Panel.new()
    _scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var scrim_style := StyleBoxFlat.new()
    scrim_style.bg_color = Color(0.03, 0.04, 0.07, 0.72)
    _scrim.add_theme_stylebox_override("panel", scrim_style)
    add_child(_scrim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _scrim.add_child(center)
    _modal = PanelContainer.new()
    _modal.custom_minimum_size = Vector2(720, 0)
    var modal_style := StyleBoxFlat.new()
    modal_style.bg_color = CREAM
    modal_style.set_corner_radius_all(14)
    modal_style.set_content_margin_all(24)
    modal_style.shadow_color = Color(0, 0, 0, 0.4)
    modal_style.shadow_size = 20
    _modal.add_theme_stylebox_override("panel", modal_style)
    center.add_child(_modal)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    _modal.add_child(col)
    _title = Label.new()
    _title.add_theme_color_override("font_color", INK)
    _title.add_theme_font_size_override("font_size", 22)
    col.add_child(_title)
    _body = VBoxContainer.new()
    _body.add_theme_constant_override("separation", 8)
    col.add_child(_body)

func _close_button() -> Button:
    var button := _button("Close  (Esc)")
    button.pressed.connect(_close)
    return button

func _open() -> void:
    _scrim.visible = true
    modal_changed.emit(true)

func _close() -> void:
    _scrim.visible = false
    _chat_log = null
    _chat_input = null
    _chat_send = null
    _sending = false
    modal_changed.emit(false)

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_ALL
    button.custom_minimum_size = Vector2(0, 40)
    button.add_theme_font_size_override("font_size", 15)
    var style := StyleBoxFlat.new()
    style.bg_color = CARD
    style.set_corner_radius_all(8)
    style.set_border_width_all(1)
    style.border_color = Color(0.82, 0.78, 0.7, 1)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", INK)
    return button

func _clear(node: Node) -> void:
    for child: Node in node.get_children():
        child.queue_free()

func _lookup(items: Variant, field: String, requested_id: String) -> Dictionary:
    for item: Variant in items if typeof(items) == TYPE_ARRAY else []:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(field, "")) == requested_id:
            return item
    return {}

func _unhandled_key_input(event: InputEvent) -> void:
    if is_modal_open() and event.is_action_pressed("ui_cancel"):
        _close()
        get_viewport().set_input_as_handled()
