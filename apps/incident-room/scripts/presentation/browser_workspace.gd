class_name BrowserWorkspace
extends Control

## Browser-styled workspace chrome. Hosts the assessment panels as tab pages so the
## desktop reads like a candidate opening tabs in a web app. Tab clicks emit
## `tab_activated`; the coordinator maps that to its existing intents (keep flow).

signal tab_activated(key: String)

const NAVY := Color(0.12, 0.16, 0.3, 1)
const CREAM := Color(0.95, 0.92, 0.86, 1)
const INK := Color(0.13, 0.17, 0.31, 1)
const MUTED := Color(0.4, 0.38, 0.44, 1)
const ACCENTS := {
    "observability_wall": Color(0.1, 0.78, 0.95, 1),
    "developer_desk": Color(0.66, 0.42, 0.94, 1),
    "release_console": Color(0.24, 0.82, 0.49, 1),
    "hypothesis": Color(0.98, 0.7, 0.25, 1),
}

@export var demo_mode := true

@onready var _tabs_box: HBoxContainer = $Frame/TabStrip/Tabs
@onready var _host: Control = $Frame/Content/PanelHost
@onready var _url: Label = $Frame/Chrome/ChromeRow/Address/Url

var _tab_defs: Array = []
var _active_key := ""
var _buttons: Dictionary = {}

func _ready() -> void:
    _apply_page_theme()
    if demo_mode:
        set_tabs([
            {"key": "observability_wall", "label": "Observability"},
            {"key": "developer_desk", "label": "Developer"},
            {"key": "release_console", "label": "Release"},
            {"key": "hypothesis", "label": "Hypothesis"},
        ])
        set_active_tab("observability_wall")
        _build_demo_page()

func set_tabs(defs: Array) -> void:
    _tab_defs = defs
    for child: Node in _tabs_box.get_children():
        child.queue_free()
    _buttons.clear()
    for def: Dictionary in defs:
        var key := str(def.get("key", ""))
        var button := Button.new()
        button.text = str(def.get("label", key))
        button.focus_mode = Control.FOCUS_ALL
        button.add_theme_font_size_override("font_size", 15)
        button.custom_minimum_size = Vector2(0, 38)
        button.pressed.connect(_on_tab_pressed.bind(key))
        _tabs_box.add_child(button)
        _buttons[key] = button
    _restyle_tabs()

func set_active_tab(key: String) -> void:
    _active_key = key
    _restyle_tabs()

func content_root() -> Control:
    return _host

func clear_page() -> void:
    for child: Node in _host.get_children():
        child.queue_free()

func set_url(text: String) -> void:
    _url.text = text

func _apply_page_theme() -> void:
    # Light "web page" theme for hosted panels. The chrome's own nodes use explicit
    # style overrides, which win over this theme, so only the tab pages are restyled.
    var t := Theme.new()
    t.set_color("font_color", "Label", INK)
    t.set_color("default_color", "RichTextLabel", INK)
    t.set_color("font_color", "Button", INK)
    t.set_color("font_hover_color", "Button", INK)
    t.set_color("font_pressed_color", "Button", INK)
    t.set_color("font_disabled_color", "Button", MUTED)
    t.set_color("font_color", "OptionButton", INK)
    t.set_color("font_hover_color", "OptionButton", INK)
    var card := StyleBoxFlat.new()
    card.bg_color = Color(0.98, 0.96, 0.92, 1)
    card.set_corner_radius_all(12)
    card.set_content_margin_all(6)
    t.set_stylebox("panel", "PanelContainer", card)
    t.set_stylebox("panel", "Panel", card)
    for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
        var box := StyleBoxFlat.new()
        box.bg_color = Color(0.93, 0.9, 0.83, 1)
        if state == "hover":
            box.bg_color = Color(0.9, 0.86, 0.77, 1)
        elif state == "disabled":
            box.bg_color = Color(0.9, 0.88, 0.83, 0.6)
        box.set_corner_radius_all(8)
        box.set_content_margin_all(9)
        box.set_border_width_all(1)
        box.border_color = Color(0.82, 0.78, 0.7, 1)
        t.set_stylebox(state, "Button", box)
        t.set_stylebox(state, "OptionButton", box)
    theme = t

func _on_tab_pressed(key: String) -> void:
    set_active_tab(key)
    tab_activated.emit(key)

func _restyle_tabs() -> void:
    for key: String in _buttons:
        var button: Button = _buttons[key]
        var accent: Color = ACCENTS.get(key, NAVY)
        var active := key == _active_key
        button.add_theme_stylebox_override("normal", _tab_style(active, accent))
        button.add_theme_stylebox_override("hover", _tab_style(active, accent, true))
        button.add_theme_stylebox_override("pressed", _tab_style(active, accent))
        button.add_theme_stylebox_override("focus", _tab_style(active, accent, true))
        button.add_theme_color_override("font_color", INK if active else CREAM)
        button.add_theme_color_override("font_hover_color", INK if active else CREAM)
        button.add_theme_color_override("font_pressed_color", INK if active else CREAM)
        button.add_theme_color_override("font_focus_color", INK if active else CREAM)

func _tab_style(active: bool, accent: Color, hover := false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = CREAM if active else Color(0.16, 0.2, 0.36, 1)
    if hover and not active:
        style.bg_color = Color(0.2, 0.25, 0.42, 1)
    style.corner_radius_top_left = 9
    style.corner_radius_top_right = 9
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 7
    style.content_margin_bottom = 9
    style.border_width_top = 3
    style.border_color = accent if active else Color(accent.r, accent.g, accent.b, 0.0)
    return style

func _card_button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.focus_mode = Control.FOCUS_ALL
    button.custom_minimum_size = Vector2(0, 44)
    button.add_theme_font_size_override("font_size", 15)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.99, 0.97, 0.93, 1)
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

func _heading(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _build_demo_page() -> void:
    clear_page()
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 30)
    margin.add_theme_constant_override("margin_top", 26)
    margin.add_theme_constant_override("margin_right", 30)
    margin.add_theme_constant_override("margin_bottom", 26)
    _host.add_child(margin)
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 12)
    margin.add_child(page)
    page.add_child(_heading("Observability Wall", 27, INK))
    page.add_child(_heading("Open evidence artifacts. Repeated views stay in the session timeline.", 15, MUTED))
    page.add_child(_card_button("📊  Latency dashboard — p99 spike at 14:02 UTC"))
    page.add_child(_card_button("📈  Error-rate panel — 4xx flat, 5xx climbing"))
    page.add_child(_card_button("🗒️  Deploy log — release r-2291 rolled out 13:58"))
    page.add_child(HSeparator.new())
    page.add_child(_heading("Scripted assistant", 18, ACCENTS["observability_wall"]))
    page.add_child(_heading("\"The p99 climb starts right after r-2291. Want me to pull the diff?\"", 15, INK))
