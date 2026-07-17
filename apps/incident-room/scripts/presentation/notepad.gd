class_name Notepad
extends Control

## Cosmetic desk notepad: a free-text scratchpad and a small sketch canvas the candidate
## can doodle on. Purely flavour — nothing here is scored, persisted, or sent anywhere.

signal closed

const INK := Color(0.13, 0.17, 0.31, 1)
const PAPER := Color(0.99, 0.98, 0.94, 1)

var _canvas: Control
var _notes: TextEdit
var _strokes: Array[PackedVector2Array] = []
var _drawing := false

func _ready() -> void:
    _build()
    visible = false

## Wipe the scratch notes + doodle so the next candidate doesn't inherit them. Flavour only
## (nothing here is scored), but the pad is a persistent scene node — main.restart_session calls this.
func reset() -> void:
    if is_instance_valid(_notes):
        _notes.clear()
    _strokes.clear()
    if is_instance_valid(_canvas):
        _canvas.queue_redraw()
    visible = false

func open_pad() -> void:
    visible = true
    modulate = Color(1, 1, 1, 0)
    var t := create_tween()
    t.tween_property(self, "modulate:a", 1.0, 0.15)

func _close() -> void:
    visible = false
    closed.emit()

func _build() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var scrim := ColorRect.new()
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.color = Color(0.03, 0.04, 0.07, 0.6)
    add_child(scrim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var pad := PanelContainer.new()
    pad.custom_minimum_size = Vector2(760, 520)
    var style := StyleBoxFlat.new()
    style.bg_color = PAPER
    style.set_corner_radius_all(12)
    style.set_content_margin_all(20)
    style.shadow_color = Color(0, 0, 0, 0.4)
    style.shadow_size = 18
    pad.add_theme_stylebox_override("panel", style)
    center.add_child(pad)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 10)
    pad.add_child(col)

    var title := Label.new()
    title.text = "📝  Desk notepad"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", INK)
    col.add_child(title)
    var hint := Label.new()
    hint.text = "Scratch notes and a doodle pad — just for you. Not scored or saved."
    hint.add_theme_color_override("font_color", Color(0.4, 0.38, 0.44, 1))
    col.add_child(hint)

    var notes := TextEdit.new()
    notes.placeholder_text = "Jot your thinking here…"
    notes.custom_minimum_size = Vector2(0, 150)
    notes.add_theme_color_override("font_color", INK)
    col.add_child(notes)
    _notes = notes

    var sketch_label := Label.new()
    sketch_label.text = "Sketch pad (drag to draw):"
    sketch_label.add_theme_color_override("font_color", INK)
    col.add_child(sketch_label)

    _canvas = Control.new()
    _canvas.custom_minimum_size = Vector2(0, 180)
    _canvas.clip_contents = true
    var cbg := StyleBoxFlat.new()
    cbg.bg_color = Color(1, 1, 1, 1)
    cbg.set_border_width_all(1)
    cbg.border_color = Color(0.8, 0.78, 0.72, 1)
    cbg.set_corner_radius_all(6)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", cbg)
    panel.custom_minimum_size = Vector2(0, 180)
    panel.add_child(_canvas)
    col.add_child(panel)
    _canvas.draw.connect(_draw_strokes)
    _canvas.gui_input.connect(_on_canvas_input)
    _canvas.mouse_filter = Control.MOUSE_FILTER_STOP

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    col.add_child(row)
    var clear_btn := _button("Clear sketch")
    clear_btn.pressed.connect(func() -> void:
        _strokes.clear()
        _canvas.queue_redraw())
    row.add_child(clear_btn)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    var close_btn := _button("Close  (Esc)")
    close_btn.pressed.connect(_close)
    row.add_child(close_btn)

func _on_canvas_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _drawing = true
            _strokes.append(PackedVector2Array([event.position]))
        else:
            _drawing = false
    elif event is InputEventMouseMotion and _drawing and not _strokes.is_empty():
        _strokes[_strokes.size() - 1].append(event.position)
        _canvas.queue_redraw()

func _draw_strokes() -> void:
    for stroke: PackedVector2Array in _strokes:
        if stroke.size() >= 2:
            _canvas.draw_polyline(stroke, INK, 2.5, true)

func _button(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_color_override("font_color", INK)
    return b

func _unhandled_key_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        _close()
        get_viewport().set_input_as_handled()
