class_name DialogueBox
extends Control

## Pokémon-style dialogue overlay: bottom panel with a speaker portrait + name and a
## typewriter body. Purely presentational — the caller supplies lines and reacts to
## `finished`. Advance with Space / Enter / click / the interact key (E).
##
## play(lines): each line is { "speaker": String, "text": String, "portrait": Texture2D|null }

signal finished

const REVEAL_INTERVAL := 0.018   # seconds per revealed character
const CREAM := Color(0.96, 0.94, 0.9, 1)
const INK := Color(0.13, 0.17, 0.31, 1)
const ACCENT := Color(0.66, 0.42, 0.94, 1)

var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _speaker: Label
var _body: RichTextLabel
var _hint: Label

var _lines: Array = []
var _index := -1
var _accum := 0.0
var _revealed := 0
var _typing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Show a sequence of lines. Emits `finished` after the last one is dismissed.
func play(lines: Array) -> void:
	_lines = lines
	_index = -1
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_advance()

func is_active() -> bool:
	return visible

## Hide immediately without emitting `finished` (used on session restart).
func dismiss() -> void:
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines = []
	_typing = false

func _build() -> void:
	# Bottom banner.
	var wrap := MarginContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	wrap.offset_top = -196
	wrap.offset_left = 24
	wrap.offset_right = -24
	wrap.offset_bottom = -24
	add_child(wrap)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.24, 0.97)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = CREAM
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	wrap.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	# Portrait (left).
	_portrait_frame = PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.95, 0.93, 0.88, 1)
	pstyle.set_corner_radius_all(10)
	pstyle.set_border_width_all(2)
	pstyle.border_color = CREAM
	_portrait_frame.add_theme_stylebox_override("panel", pstyle)
	_portrait_frame.custom_minimum_size = Vector2(132, 132)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(116, 116)
	_portrait_frame.add_child(_portrait)

	# Text column (right).
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)

	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", ACCENT)
	_speaker.add_theme_font_size_override("font_size", 20)
	col.add_child(_speaker)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", CREAM)
	_body.add_theme_font_size_override("normal_font_size", 18)
	col.add_child(_body)

	_hint = Label.new()
	_hint.text = "▾  Space / click / E"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8, 1))
	_hint.add_theme_font_size_override("font_size", 13)
	col.add_child(_hint)

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_end()
		return
	var line: Dictionary = _lines[_index]
	_speaker.text = str(line.get("speaker", ""))
	var tex: Variant = line.get("portrait", null)
	_portrait_frame.visible = tex is Texture2D
	_portrait.texture = tex if tex is Texture2D else null
	_body.text = str(line.get("text", ""))
	_body.visible_characters = 0
	_revealed = 0
	_accum = 0.0
	_typing = true

func _end() -> void:
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines = []
	finished.emit()

func _process(delta: float) -> void:
	if not _typing:
		return
	var total := _body.get_total_character_count()
	_accum += delta
	while _accum >= REVEAL_INTERVAL and _revealed < total:
		_accum -= REVEAL_INTERVAL
		_revealed += 1
		_body.visible_characters = _revealed
		# Soft blip on non-space chars, every other char, to avoid a harsh buzz.
		if _revealed % 2 == 0:
			var ch := _body.get_parsed_text().substr(_revealed - 1, 1)
			if ch.strip_edges() != "":
				_sfx_blip()
	if _revealed >= total:
		_typing = false

# Advance on click / Space / Enter / interact(E). Reveal-all first, then next line.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var advance := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance = true
	if not advance:
		return
	accept_event()
	advance_line()

## Advance one step: if still typing, reveal the whole current line; otherwise show the
## next line (or finish after the last). Public so it is unit-testable without input frames.
func advance_line() -> void:
	if not visible:
		return
	_sfx_click()
	if _typing:
		_body.visible_characters = -1
		_revealed = _body.get_total_character_count()
		_typing = false
	else:
		_advance()

func _sfx_blip() -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null and s.has_method("blip"):
		s.blip()

func _sfx_click() -> void:
	var s := get_node_or_null("/root/Sfx")
	if s != null and s.has_method("click"):
		s.click()
