class_name PauseMenu
extends Control

## Esc overlay for demoing: Resume, Restart (new candidate), and a mute toggle.
## Reset reuses the coordinator's existing restart_session(); this is presentation only.

signal resume_requested
signal restart_requested

const CREAM := Color(0.96, 0.94, 0.9, 1)
const INK := Color(0.13, 0.17, 0.31, 1)

var _mute_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_mute()

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_open() -> bool:
	return visible

func _build() -> void:
	var scrim := Panel.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim_style := StyleBoxFlat.new()
	scrim_style.bg_color = Color(0.03, 0.04, 0.07, 0.72)
	scrim.add_theme_stylebox_override("panel", scrim_style)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.12, 0.24, 0.98)
	pstyle.set_corner_radius_all(14)
	pstyle.set_border_width_all(3)
	pstyle.border_color = CREAM
	pstyle.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)

	var resume := _button("Resume  (Esc)")
	resume.pressed.connect(func() -> void:
		_click()
		resume_requested.emit())
	col.add_child(resume)

	var restart := _button("Restart — new candidate")
	restart.pressed.connect(func() -> void:
		_click()
		restart_requested.emit())
	col.add_child(restart)

	_mute_btn = _button("Sound: On")
	_mute_btn.pressed.connect(_on_mute_pressed)
	col.add_child(_mute_btn)

func _on_mute_pressed() -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null and s.has_method("set_muted") and s.has_method("is_muted"):
		s.set_muted(not s.is_muted())
	_click()
	_refresh_mute()

func _refresh_mute() -> void:
	if _mute_btn == null:
		return
	var s := get_node_or_null("/root/Sfx")
	var muted: bool = s != null and s.has_method("is_muted") and s.is_muted()
	_mute_btn.text = "Sound: Off (muted)" if muted else "Sound: On"

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.2, 0.36, 1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	b.add_theme_color_override("font_color", CREAM)
	return b

func _click() -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null and s.has_method("click"):
		s.click()
