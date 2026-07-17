class_name BrowserWorkspace
extends Control

## Browser-styled 2D workspace: the candidate uses the assessment as tabs in a web
## app (Brief / Evidence / Assistant / Files & Tests / Submit + a Report view). Every
## tab is built in code from scenario data; the view only emits intents and renders
## from the snapshot, while the coordinator owns the domain session (keep flow).

signal initial_hypothesis_submitted(hypothesis_id: String, confidence: int)
signal evidence_view_requested(artifact_id: String)
signal disposition_submitted(option_id: String)
signal verification_requested(test_id: String, remediation_id: String)
signal revision_submitted(hypothesis_id: String, confidence: int, fact_ids: Array)
signal final_submission_requested(submission: Dictionary)
signal restart_requested
signal leave_requested
signal notepad_requested

const NAVY := Color(0.12, 0.16, 0.3, 1)
const CREAM := Color(0.95, 0.92, 0.86, 1)
const INK := Color(0.13, 0.17, 0.31, 1)
const MUTED := Color(0.4, 0.38, 0.44, 1)
const CARD := Color(0.99, 0.97, 0.93, 1)
const CARD_BORDER := Color(0.82, 0.78, 0.7, 1)
const ACCENT := {
    "home": Color(0.08, 0.5, 0.46, 1),
    "brief": Color(0.98, 0.7, 0.25, 1),
    "evidence": Color(0.1, 0.78, 0.95, 1),
    "assistant": Color(0.66, 0.42, 0.94, 1),
    "tests": Color(0.24, 0.82, 0.49, 1),
    "submit": Color(0.95, 0.45, 0.55, 1),
    "report": Color(0.98, 0.7, 0.25, 1),
}
const TAB_DEFS := [
    {"key": "prompting", "label": "Codex"},
    {"key": "home", "label": "Home"},
    {"key": "brief", "label": "Brief"},
    {"key": "evidence", "label": "Evidence"},
    {"key": "assistant", "label": "Assistant"},
    {"key": "tests", "label": "Files & Tests"},
    {"key": "submit", "label": "Submit"},
]

@export var demo_mode := false
## Live in-workspace copilot endpoint (the senior-proxy assistant route).
@export var assistant_proxy_url := "https://senior-proxy-production.up.railway.app/api/assistant/chat"

@onready var _tabs_box: HBoxContainer = $Frame/TabStrip/Tabs
@onready var _host: Control = $Frame/Content/PanelHost
@onready var _url: Label = $Frame/Chrome/ChromeRow/Address/Url

var _scenario: Dictionary = {}
var _pages: Dictionary = {}
var _buttons: Dictionary = {}
var _active := ""
var _started := false
var _report_available := false

var _brief_option: OptionButton
var _brief_confidence: HSlider
var _brief_confidence_label: Label
var _brief_confirm: Button
var _brief_status: Label

var _evidence_detail: RichTextLabel
var _evidence_buttons: Dictionary = {}

var _disposition_option: OptionButton
var _disposition_confirm: Button
var _disposition_status: Label
var _assistant_http: HTTPRequest
var _assistant_log: RichTextLabel
var _assistant_input: LineEdit
var _assistant_send: Button
var _assistant_history: Array = []
var _assistant_sending := false

var _codex_editor: CodeEdit
var _codex_http: HTTPRequest
var _codex_log: RichTextLabel
var _codex_input: TextEdit
var _codex_send_btn: Button
var _codex_submit_btn: Button
var _codex_run_output: RichTextLabel
var _codex_status: Label
var _codex_history: Array = []
var _codex_busy := false

var _tests_remediation: OptionButton
var _test_result_labels: Dictionary = {}

var _revise_current: Label
var _revise_option: OptionButton
var _revise_confidence: HSlider
var _revise_confidence_label: Label
var _revise_facts: ItemList
var _revise_button: Button
var _submit_root: OptionButton
var _submit_remediation: OptionButton
var _submit_rollback: OptionButton
var _submit_risks: ItemList
var _submit_assumptions: ItemList
var _submit_validation: ItemList
var _submit_evidence: ItemList
var _submit_confidence: HSlider
var _submit_confidence_label: Label
var _submit_rationale: TextEdit
var _submit_button: Button
var _submit_status: Label

var _report_heading: Label
var _report_status: Label
var _report_score: RichTextLabel
var _report_details: RichTextLabel
var _report_notices: RichTextLabel

func _ready() -> void:
    _apply_page_theme()
    _assistant_http = HTTPRequest.new()
    add_child(_assistant_http)
    _assistant_http.request_completed.connect(_on_assistant_response)
    _codex_http = HTTPRequest.new()
    add_child(_codex_http)
    _codex_http.request_completed.connect(_on_codex_response)
    var chrome_row := $Frame/Chrome/ChromeRow as HBoxContainer
    var notepad := Button.new()
    notepad.text = "📝 Notepad"
    notepad.focus_mode = Control.FOCUS_ALL
    notepad.add_theme_font_size_override("font_size", 13)
    notepad.pressed.connect(func() -> void: notepad_requested.emit())
    chrome_row.add_child(notepad)
    var leave := Button.new()
    leave.text = "⟵ Back to desk"
    leave.focus_mode = Control.FOCUS_ALL
    leave.add_theme_font_size_override("font_size", 13)
    leave.pressed.connect(func() -> void: leave_requested.emit())
    chrome_row.add_child(leave)
    if demo_mode and _scenario.is_empty():
        var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
        if loaded.ok:
            configure(loaded.scenario)
            set_started(true)

# --- Public API --------------------------------------------------------------

func configure(scenario: Dictionary) -> void:
    _scenario = scenario
    _started = false
    _report_available = false
    for child: Node in _host.get_children():
        child.queue_free()
    _pages.clear()
    _build_tabs()
    _build_home_page()
    _build_brief_page()
    _build_prompting_page()
    _build_evidence_page()
    _build_assistant_page()
    _build_tests_page()
    _build_submit_page()
    _build_report_page()
    set_url("🔒  vibeproof.app / incident / %s" % str(scenario.get("scenario_id", "session")))
    set_active_tab("brief")

func set_started(started: bool) -> void:
    _started = started
    _refresh_tab_states()
    if started and _active == "brief":
        set_active_tab("evidence")

func show_report(summary: Dictionary) -> void:
    _report_available = true
    _populate_report(summary)
    _refresh_tab_states()
    set_active_tab("report")

## Backend grading (set by the coordinator when a grading backend is configured).
func show_backend_pending() -> void:
    _report_available = true
    if _report_score != null:
        _report_score.text = "[b]Grading…[/b]  sending your session to the assessment backend."
    _refresh_tab_states()
    set_active_tab("report")

func show_backend_score(result: Dictionary) -> void:
    if _report_score == null:
        return
    var total := float(result.get("total", 0.0))
    var maxv := float(result.get("max", 0.0))
    var pct := int(round(total / maxv * 100.0)) if maxv > 0.0 else 0
    var lines := PackedStringArray([
        "[b]Graded by the assessment backend[/b]",
        "Deterministic score: %.1f / %.1f  (%d%%)" % [total, maxv, pct],
    ])
    for c: Variant in result.get("criteria", []):
        var cd: Dictionary = c
        var status := str(cd.get("status", ""))
        var mark := "✓" if status == "met" else ("—" if status == "excluded" else "✗")
        lines.append("  %s %s" % [mark, str(cd.get("label", cd.get("criterion_id", "")))])
    _report_score.text = "\n".join(lines)
    if _report_heading != null:
        _report_heading.text = "Proof Replay — graded"

func show_backend_error(message: String) -> void:
    if _report_score != null:
        _report_score.text = "[b]Backend grading unavailable[/b]  %s\nYour session is saved; a reviewer can grade it manually." % message

func refresh(snapshot: Dictionary) -> void:
    _refresh_brief(snapshot)
    _refresh_evidence(snapshot)
    _refresh_assistant(snapshot)
    _refresh_tests(snapshot)
    _refresh_submit(snapshot)

func set_active_tab(key: String) -> void:
    if not _pages.has(key):
        return
    _active = key
    for page_key: String in _pages:
        (_pages[page_key] as Control).visible = page_key == key
    _restyle_tabs()

func set_url(text: String) -> void:
    _url.text = text

# --- Tab strip ---------------------------------------------------------------

func _build_tabs() -> void:
    for child: Node in _tabs_box.get_children():
        child.queue_free()
    _buttons.clear()
    for def: Dictionary in TAB_DEFS:
        _add_tab_button(str(def.key), str(def.label))

func _add_tab_button(key: String, label: String) -> void:
    var button := Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 15)
    button.custom_minimum_size = Vector2(0, 38)
    button.pressed.connect(func() -> void: _on_tab_pressed(key))
    _tabs_box.add_child(button)
    _buttons[key] = button

func _on_tab_pressed(key: String) -> void:
    if key == "report" and not _report_available:
        return
    if key != "home" and key != "brief" and key != "report" and not _started:
        # These tabs unlock once the candidate records an initial hypothesis; send them
        # to the Brief tab (where that happens) instead of a dead tap.
        set_active_tab("brief")
        if _brief_status != null:
            _brief_status.text = "🔒 Record your initial hypothesis below to unlock the workspace."
        return
    set_active_tab(key)

func _refresh_tab_states() -> void:
    if not _buttons.has("report") and _report_available:
        _add_tab_button("report", "Report")
    _restyle_tabs()

func _restyle_tabs() -> void:
    for key: String in _buttons:
        var button: Button = _buttons[key]
        var accent: Color = ACCENT.get(key, NAVY)
        var active := key == _active
        var locked := (key != "home" and key != "brief" and key != "report" and not _started) or (key == "report" and not _report_available)
        button.disabled = locked
        button.add_theme_stylebox_override("normal", _tab_style(active, accent))
        button.add_theme_stylebox_override("hover", _tab_style(active, accent, true))
        button.add_theme_stylebox_override("pressed", _tab_style(active, accent))
        button.add_theme_stylebox_override("focus", _tab_style(active, accent, true))
        button.add_theme_stylebox_override("disabled", _tab_style(false, accent))
        var text_color := INK if active else (Color(0.5, 0.55, 0.7, 1) if locked else CREAM)
        for slot: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
            button.add_theme_color_override(slot, text_color)

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

# --- Page scaffolding --------------------------------------------------------

func _page_body(key: String) -> VBoxContainer:
    var page := MarginContainer.new()
    page.name = "Page_" + key
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.add_theme_constant_override("margin_left", 34)
    page.add_theme_constant_override("margin_top", 24)
    page.add_theme_constant_override("margin_right", 34)
    page.add_theme_constant_override("margin_bottom", 24)
    page.visible = false
    _host.add_child(page)
    _pages[key] = page
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)
    var body := VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    scroll.add_child(body)
    return body

## Codex keeps its header and columns fixed. Each column owns its own scroll area,
## so a long problem statement never scrolls the conversation or run output away.
func _fixed_page_body(key: String) -> VBoxContainer:
    var page := MarginContainer.new()
    page.name = "Page_" + key
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.add_theme_constant_override("margin_left", 34)
    page.add_theme_constant_override("margin_top", 24)
    page.add_theme_constant_override("margin_right", 34)
    page.add_theme_constant_override("margin_bottom", 24)
    page.visible = false
    _host.add_child(page)
    _pages[key] = page
    var body := VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    page.add_child(body)
    return body

# --- Brief -------------------------------------------------------------------

func _build_home_page() -> void:
    var body := _page_body("home")
    body.add_child(_heading("Welcome to VibeProof", 31, NAVY))
    body.add_child(_heading("Build with AI. Prove you know why it works. This short, AI-allowed engineering Ownership Challenge lets you show how you investigate, verify, and explain technical work.", 17, MUTED))

    var start := _flat_button("Begin incident briefing  ➡")
    start.custom_minimum_size = Vector2(0, 46)
    start.pressed.connect(func() -> void: set_active_tab("brief"))
    body.add_child(start)

    body.add_child(HSeparator.new())
    body.add_child(_heading("What you will do", 21, INK))
    var journey := HBoxContainer.new()
    journey.add_theme_constant_override("separation", 12)
    journey.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(journey)
    _add_home_step(journey, "01", "Investigate", "Read the incident brief, inspect the available evidence, and record a working hypothesis.", ACCENT["evidence"])
    _add_home_step(journey, "02", "Use AI responsibly", "Ask focused questions, then check assumptions before relying on an AI suggestion.", ACCENT["assistant"])
    _add_home_step(journey, "03", "Explain your decision", "Submit an evidence-backed recommendation with validation steps and known risks.", ACCENT["submit"])

    body.add_child(HSeparator.new())
    body.add_child(_heading("What VibeProof records", 21, INK))
    body.add_child(_heading("The session records evidence you inspect, hypotheses you record or revise, AI prompts and responses, verification choices, and your final recommendation. A human reviewer receives a chronological Proof Replay.", 15, MUTED))
    body.add_child(_heading("What does not affect your result", 17, ACCENT["home"]))
    body.add_child(_heading("Navigation speed, gaming experience, typing speed, and whether you use AI are not scored. This prototype does not make an employment decision.", 15, MUTED))

func _add_home_step(parent: Container, number: String, title: String, description: String, accent: Color) -> void:
    var card := _add_workspace_card(parent, number, accent)
    (card.get_parent() as PanelContainer).custom_minimum_size = Vector2(235, 0)
    card.add_child(_heading(title, 17, INK))
    card.add_child(_heading(description, 14, MUTED))

func _build_brief_page() -> void:
    var body := _page_body("brief")
    body.add_child(_heading("%s — %s" % [_scenario.get("title", "Incident briefing"), _scenario.get("role", "Candidate")], 27, INK))
    body.add_child(_richtext(str(_scenario.get("brief", "")), 90))
    body.add_child(HSeparator.new())
    body.add_child(_heading("Record your initial hypothesis to unlock Evidence, Assistant, Files & Tests, and Submit.", 16, ACCENT["brief"]))
    _brief_option = _option(_scenario.get("hypotheses", []), "hypothesis_id", "label")
    body.add_child(_brief_option)
    _brief_confidence = _slider()
    body.add_child(_brief_confidence)
    _brief_confidence_label = _heading("Confidence: 50%", 15, INK)
    body.add_child(_brief_confidence_label)
    _brief_confirm = _flat_button("Record initial hypothesis")
    _brief_confirm.disabled = true
    body.add_child(_brief_confirm)
    _brief_status = _heading("", 15, ACCENT["brief"])
    body.add_child(_brief_status)
    _brief_option.item_selected.connect(func(_i: int) -> void: _update_brief_confirm())
    _brief_confidence.value_changed.connect(func(value: float) -> void:
        _brief_confidence_label.text = "Confidence: %d%%" % int(value))
    _brief_confirm.pressed.connect(func() -> void:
        if not _brief_confirm.disabled:
            initial_hypothesis_submitted.emit(str(_brief_option.get_item_metadata(_brief_option.selected)), int(_brief_confidence.value)))

func _build_prompting_page() -> void:
    var body := _fixed_page_body("prompting")
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 12)
    top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    body.add_child(top)
    var title := VBoxContainer.new()
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(title)
    title.add_child(_heading("Codex", 27, INK))
    title.add_child(_heading("Prompt the assistant to edit the code inline, tweak it yourself, then run and submit.", 14, MUTED))
    var timer_label := _heading("Time remaining 45:00", 15, ACCENT["assistant"])
    timer_label.custom_minimum_size = Vector2(170, 40)
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    top.add_child(timer_label)
    var run_button := _flat_button("▶ Run")
    run_button.custom_minimum_size = Vector2(88, 40)
    run_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    top.add_child(run_button)
    _codex_submit_btn = _flat_button("Submit")
    _codex_submit_btn.custom_minimum_size = Vector2(94, 40)
    _codex_submit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _codex_submit_btn.disabled = true
    top.add_child(_codex_submit_btn)

    var workspace := HBoxContainer.new()
    workspace.add_theme_constant_override("separation", 14)
    workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(workspace)

    var incident_card := _add_scrollable_workspace_card(workspace, "PROBLEM", ACCENT["brief"])
    incident_card.add_child(_heading("%s — %s" % [_scenario.get("title", "Incident briefing"), _scenario.get("role", "Candidate")], 18, INK))
    incident_card.add_child(_richtext(str(_scenario.get("brief", "")), 130))
    incident_card.add_child(HSeparator.new())
    incident_card.add_child(_heading("What to include", 15, ACCENT["brief"]))
    incident_card.add_child(_heading("Keep authentication first and rendering last, and make the independent lookups run concurrently.", 14, MUTED))

    # The editor Codex writes into and the candidate edits. Native CodeEdit gives line
    # numbers, caret, and syntax highlight for free, and it runs in the web export.
    var editor_card := _add_workspace_card(workspace, "src/watch_page_orchestrator.ts", ACCENT["tests"])
    var editor_panel := editor_card.get_parent() as PanelContainer
    editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    editor_panel.size_flags_stretch_ratio = 1.7
    editor_panel.custom_minimum_size = Vector2(360, 0)
    editor_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _codex_editor = _make_code_editor(_seed_code())
    _codex_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    editor_card.add_child(_codex_editor)

    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(320, 0)
    right.add_theme_constant_override("separation", 14)
    workspace.add_child(right)

    var chat_card := _add_scrollable_workspace_card(right, "CODEX", ACCENT["assistant"])
    _codex_log = RichTextLabel.new()
    _codex_log.bbcode_enabled = true
    _codex_log.fit_content = true
    _codex_log.scroll_active = true
    _codex_log.custom_minimum_size = Vector2(0, 210)
    _codex_log.add_theme_color_override("default_color", INK)
    chat_card.add_child(_codex_log)
    _codex_history.clear()
    _codex_say("Codex", "Tell me what to change — e.g. \"run the independent lookups concurrently\". I'll edit the file in the editor.", ACCENT["assistant"])
    var chat_row := HBoxContainer.new()
    chat_row.add_theme_constant_override("separation", 8)
    chat_card.add_child(chat_row)
    _codex_input = TextEdit.new()
    _codex_input.custom_minimum_size = Vector2(0, 64)
    _codex_input.placeholder_text = "Ask Codex to change the code…"
    _codex_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _codex_input.focus_mode = Control.FOCUS_ALL
    chat_row.add_child(_codex_input)
    _codex_send_btn = _flat_button("Send")
    _codex_send_btn.custom_minimum_size = Vector2(76, 38)
    _codex_send_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    chat_row.add_child(_codex_send_btn)

    var output_card := _add_scrollable_workspace_card(right, "RUN OUTPUT", ACCENT["tests"])
    _codex_run_output = _richtext("[b]No run yet.[/b]\nEdit the code, then select [b]Run[/b].", 120)
    _codex_run_output.scroll_active = true
    output_card.add_child(_codex_run_output)
    _codex_status = _heading("", 13, ACCENT["submit"])
    _codex_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    output_card.add_child(_codex_status)
    var submit_sheet := Control.new()
    submit_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    submit_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
    submit_sheet.visible = false
    (_pages["prompting"] as Control).add_child(submit_sheet)
    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.05, 0.07, 0.12, 0.28)
    submit_sheet.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    submit_sheet.add_child(center)
    var sheet := PanelContainer.new()
    sheet.custom_minimum_size = Vector2(430, 0)
    var sheet_style := StyleBoxFlat.new()
    sheet_style.bg_color = Color(0.98, 0.97, 0.94, 1)
    sheet_style.set_corner_radius_all(16)
    sheet_style.set_border_width_all(1)
    sheet_style.border_color = Color(0.78, 0.76, 0.7, 1)
    sheet_style.content_margin_left = 28
    sheet_style.content_margin_right = 28
    sheet_style.content_margin_top = 24
    sheet_style.content_margin_bottom = 22
    sheet.add_theme_stylebox_override("panel", sheet_style)
    center.add_child(sheet)
    var sheet_content := VBoxContainer.new()
    sheet_content.add_theme_constant_override("separation", 12)
    sheet.add_child(sheet_content)
    var sheet_title := _heading("Submit your work?", 22, INK)
    sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sheet_content.add_child(sheet_title)
    var sheet_message := _heading("Your current code and run result will be recorded for this local prototype. You cannot edit this submission afterwards.", 14, MUTED)
    sheet_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sheet_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sheet_content.add_child(sheet_message)
    var sheet_actions := HBoxContainer.new()
    sheet_actions.alignment = BoxContainer.ALIGNMENT_CENTER
    sheet_actions.add_theme_constant_override("separation", 10)
    sheet_content.add_child(sheet_actions)
    var cancel_sheet := _flat_button("Cancel")
    cancel_sheet.custom_minimum_size = Vector2(110, 40)
    var confirm_sheet := _flat_button("Submit")
    confirm_sheet.custom_minimum_size = Vector2(110, 40)
    var confirm_style := StyleBoxFlat.new()
    confirm_style.bg_color = Color(0.12, 0.5, 0.46, 1)
    confirm_style.set_corner_radius_all(8)
    confirm_style.set_content_margin_all(9)
    confirm_sheet.add_theme_stylebox_override("normal", confirm_style)
    confirm_sheet.add_theme_stylebox_override("hover", confirm_style)
    confirm_sheet.add_theme_stylebox_override("pressed", confirm_style)
    confirm_sheet.add_theme_color_override("font_color", Color.WHITE)
    sheet_actions.add_child(confirm_sheet)
    sheet_actions.add_child(cancel_sheet)

    _codex_send_btn.pressed.connect(_codex_prompt)
    _codex_input.gui_input.connect(func(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and not event.shift_pressed:
            _codex_input.accept_event()
            _codex_prompt())
    run_button.pressed.connect(func() -> void: _codex_run())
    _codex_submit_btn.pressed.connect(func() -> void:
        submit_sheet.visible = true
        confirm_sheet.grab_focus.call_deferred())
    cancel_sheet.pressed.connect(func() -> void: submit_sheet.visible = false)
    confirm_sheet.pressed.connect(func() -> void:
        submit_sheet.visible = false
        _codex_status.text = "Submitted locally for this prototype. Your final code was recorded."
        _codex_submit_btn.disabled = true)

    var started_at := Time.get_ticks_msec()
    var ticker := Timer.new()
    ticker.wait_time = 1.0
    ticker.timeout.connect(func() -> void:
        var remaining := maxi(0, 45 * 60 - int((Time.get_ticks_msec() - started_at) / 1000))
        timer_label.text = "Time remaining %02d:%02d" % [remaining / 60, remaining % 60])
    body.add_child(ticker)
    ticker.start()

# --- Codex editor: prompt → the assistant writes code inline; the candidate edits it too ---

func _seed_code() -> String:
    var orchestrator := _lookup(_scenario.get("artifacts", []), "artifact_id", "homepage_orchestrator")
    var out := PackedStringArray()
    for line: Variant in orchestrator.get("content", []):
        out.append(str(line))
    return "\n".join(out)

func _make_code_editor(seed: String) -> CodeEdit:
    var editor := CodeEdit.new()
    editor.text = seed
    editor.gutters_draw_line_numbers = true
    editor.highlight_current_line = true
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.add_theme_font_size_override("font_size", 14)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.11, 0.16, 1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(10)
    editor.add_theme_stylebox_override("normal", style)
    editor.add_theme_stylebox_override("focus", style)
    editor.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
    editor.add_theme_color_override("caret_color", Color(0.7, 0.9, 1, 1))
    editor.add_theme_color_override("line_number_color", Color(0.45, 0.55, 0.7, 1))
    var hl := CodeHighlighter.new()
    hl.number_color = Color(0.98, 0.7, 0.45)
    hl.symbol_color = Color(0.62, 0.8, 0.95)
    hl.function_color = Color(0.5, 0.82, 0.88)
    hl.member_variable_color = Color(0.8, 0.86, 0.92)
    for keyword: String in ["await", "async", "const", "let", "var", "return", "function"]:
        hl.add_keyword_color(keyword, Color(0.66, 0.55, 0.94))
    hl.add_color_region("//", "", Color(0.45, 0.55, 0.6), true)
    editor.syntax_highlighter = hl
    return editor

func _codex_prompt() -> void:
    if _codex_busy or _codex_input == null:
        return
    var text := _codex_input.text.strip_edges()
    if text.is_empty():
        return
    _codex_input.text = ""
    _codex_say("You", text, INK)
    _codex_history.append({"role": "user", "content": text})
    _codex_busy = true
    _codex_send_btn.disabled = true
    _codex_say("Codex", "…", MUTED)
    var payload := {"messages": _codex_history, "task": _codex_context()}
    var headers := PackedStringArray(["Content-Type: application/json"])
    var err := _codex_http.request(assistant_proxy_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        _codex_reply("(Assistant offline — applying the reference concurrency fix.)", _reference_fix())

func _codex_context() -> String:
    var parts := PackedStringArray([
        str(_scenario.get("brief", "")),
        "The candidate is editing src/watch_page_orchestrator.ts. Current contents:",
        _codex_editor.text if is_instance_valid(_codex_editor) else "",
        "When you change the code, reply with the FULL updated file in one ```ts fenced block.",
    ])
    return "\n".join(parts)

func _on_codex_response(_result: int, code: int, _headers: PackedStringArray, resp: PackedByteArray) -> void:
    if not _codex_busy:
        return
    var reply := ""
    if code == 200:
        var parsed: Variant = JSON.parse_string(resp.get_string_from_utf8())
        if parsed is Dictionary:
            reply = str(parsed.get("reply", ""))
    if reply.is_empty():
        _codex_reply("(Assistant offline — applying the reference concurrency fix.)", _reference_fix())
        return
    _codex_reply(reply, _extract_code(reply))

func _codex_reply(text: String, code: String) -> void:
    _codex_history.append({"role": "assistant", "content": text})
    _replace_thinking(text)
    if code.is_empty():
        _codex_finish()
        return
    _type_code(code)

func _codex_finish() -> void:
    _codex_busy = false
    if _codex_send_btn != null:
        _codex_send_btn.disabled = false

func _replace_thinking(text: String) -> void:
    if _codex_log == null:
        return
    var lines := _codex_log.text.split("\n", false)
    if lines.size() > 0 and lines[lines.size() - 1].contains("…"):
        lines.remove_at(lines.size() - 1)
    _codex_log.text = "\n".join(lines) + ("\n" if lines.size() > 0 else "")
    _codex_say("Codex", text, ACCENT["assistant"])

func _codex_say(speaker: String, text: String, color: Color) -> void:
    if _codex_log == null:
        return
    _codex_log.text += "[color=#%s][b]%s[/b][/color]  %s\n" % [color.to_html(false), speaker, text]

## Pull the first ```fenced``` block out of a reply, dropping the opening ```lang line.
func _extract_code(reply: String) -> String:
    var start := reply.find("```")
    if start < 0:
        return ""
    var after := reply.find("\n", start)
    if after < 0:
        return ""
    var end := reply.find("```", after + 1)
    if end < 0:
        return ""
    return reply.substr(after + 1, end - after - 1).strip_edges()

func _reference_fix() -> String:
    return "\n".join(PackedStringArray([
        "await requireAuthenticatedUser(userId);",
        "const [details, recommendations, comments] = await Promise.all([",
        "  getVideoDetails(videoId),",
        "  getRecommendations(videoId),",
        "  getComments(videoId),",
        "]);",
        "return renderWatchPage({ details, recommendations, comments });",
    ]))

# ponytail: fixed 8ms/char typewriter — good enough for the demo; swap for a Tween if you want easing.
func _type_code(code: String) -> void:
    if not is_instance_valid(_codex_editor):
        _codex_finish()
        return
    _codex_editor.editable = false
    _codex_editor.text = ""
    for i: int in range(code.length()):
        if not is_instance_valid(_codex_editor):
            _codex_finish()
            return
        _codex_editor.text += code[i]
        var last := _codex_editor.get_line_count() - 1
        _codex_editor.set_caret_line(last)
        _codex_editor.set_caret_column(_codex_editor.get_line(last).length())
        _codex_editor.scroll_vertical = last
        await get_tree().create_timer(0.008).timeout
    _codex_editor.editable = true
    if _codex_submit_btn != null:
        _codex_submit_btn.disabled = false
    if _codex_status != null:
        _codex_status.text = "Codex updated the file. Edit it if you like, then Run or Submit."
    _codex_finish()

# ponytail: mocked heuristic, not real execution — matches the prototype's other mocked runs.
func _codex_run() -> void:
    if _codex_editor == null:
        return
    var code := _codex_editor.text
    var auth_at := code.find("requireAuthenticatedUser")
    var render_at := code.find("renderWatchPage")
    var ordered := auth_at >= 0 and render_at >= 0 and auth_at < render_at
    var concurrent := code.contains("Promise.all")
    var passed := ordered and concurrent
    var result := "[color=#23834d][b]PASS[/b][/color]" if passed else "[color=#b94040][b]NEEDS WORK[/b][/color]"
    var score := (1 if ordered else 0) + (1 if concurrent else 0)
    var checks := "2 / 2 mocked checks passed — independent lookups run concurrently, ordering preserved." if passed else "%d / 2 mocked checks passed — keep auth first and render last, and run the independent lookups concurrently (Promise.all)." % score
    _codex_run_output.text = "%s\n%s\n\n[b]Prototype note[/b]\nThis local result is mocked; it does not execute code." % [result, checks]
    if passed:
        _codex_submit_btn.disabled = false
    _codex_status.text = "Run complete. Submit is enabled." if passed else "Adjust the code, then run again."

func _update_brief_confirm() -> void:
    # The slider defaults to a valid, displayed 50%; only a hypothesis choice is required.
    _brief_confirm.disabled = _brief_option.selected < 0

func _refresh_brief(snapshot: Dictionary) -> void:
    if _brief_status == null:
        return
    var initial: Dictionary = snapshot.get("initial_hypothesis", {})
    if initial.is_empty():
        return
    _brief_status.text = "Recorded: %s at %d%% confidence." % [_hypothesis_label(str(initial.get("hypothesis_id", ""))), int(initial.get("confidence", 0))]
    _brief_option.disabled = true
    _brief_confidence.editable = false
    _brief_confirm.visible = false

# --- Evidence ----------------------------------------------------------------

func _build_evidence_page() -> void:
    var body := _page_body("evidence")
    body.add_child(_heading("Evidence", 27, INK))
    body.add_child(_heading("Open any artifact to read it. Every view is recorded in the session timeline.", 15, MUTED))
    _evidence_buttons.clear()
    for artifact: Dictionary in _scenario.get("artifacts", []):
        var artifact_id := str(artifact.get("artifact_id", ""))
        var station := _lookup(_scenario.get("stations", []), "station_id", str(artifact.get("station_id", "")))
        var button := _card_button("%s   ·   %s" % [artifact.get("title", artifact_id), station.get("title", artifact.get("station_id", ""))])
        button.pressed.connect(func() -> void:
            evidence_view_requested.emit(artifact_id)
            _show_artifact(artifact))
        body.add_child(button)
        _evidence_buttons[artifact_id] = button
    body.add_child(HSeparator.new())
    _evidence_detail = _richtext("Select an artifact to read its contents.", 150)
    body.add_child(_evidence_detail)

func _show_artifact(artifact: Dictionary) -> void:
    var lines := PackedStringArray(["[b]%s[/b]" % str(artifact.get("title", ""))])
    for line: Variant in artifact.get("content", []):
        lines.append("• %s" % str(line))
    _evidence_detail.text = "\n".join(lines)

func _refresh_evidence(snapshot: Dictionary) -> void:
    var viewed: Array = snapshot.get("viewed_artifact_ids", [])
    for artifact_id: String in _evidence_buttons:
        var button: Button = _evidence_buttons[artifact_id]
        var base: String = button.text.split("   ✓")[0]
        button.text = base + ("   ✓ viewed" if viewed.has(artifact_id) else "")

# --- Assistant ---------------------------------------------------------------

func _build_assistant_page() -> void:
    var body := _page_body("assistant")
    var interaction: Dictionary = _scenario.get("ai_interaction", {})
    body.add_child(_heading("Codex", 27, INK))
    body.add_child(_heading("Prompt Codex to help you resolve the incident. It reasons over the code and evidence and proposes fixes — it won't hand you the answer. Every prompt is recorded.", 14, MUTED))
    _add_code_panel(body)
    _assistant_log = RichTextLabel.new()
    _assistant_log.bbcode_enabled = true
    _assistant_log.fit_content = true
    _assistant_log.scroll_active = true
    _assistant_log.custom_minimum_size = Vector2(0, 240)
    _assistant_log.add_theme_color_override("default_color", INK)
    body.add_child(_assistant_log)
    _assistant_history.clear()
    _assistant_say("Codex", "Ready. I can see src/watch_page_orchestrator.ts and the incident evidence. Tell me what to investigate or ask me how to resolve the latency — I'll walk the reasoning with you.", ACCENT["assistant"])
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    body.add_child(row)
    _assistant_input = LineEdit.new()
    _assistant_input.placeholder_text = "Ask Codex to find or resolve the bottleneck…"
    _assistant_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _assistant_input.focus_mode = Control.FOCUS_ALL
    row.add_child(_assistant_input)
    _assistant_send = _flat_button("Send")
    _assistant_send.custom_minimum_size = Vector2(90, 0)
    row.add_child(_assistant_send)
    _assistant_input.text_submitted.connect(func(_t: String) -> void: _send_assistant())
    _assistant_send.pressed.connect(_send_assistant)
    body.add_child(HSeparator.new())
    body.add_child(_heading("How did you handle the assistant's input?", 16, INK))
    _disposition_option = _option(interaction.get("dispositions", []), "option_id", "disposition", true)
    body.add_child(_disposition_option)
    _disposition_confirm = _flat_button("Record how I handled the assistant")
    _disposition_confirm.disabled = true
    body.add_child(_disposition_confirm)
    _disposition_status = _heading("", 15, ACCENT["assistant"])
    body.add_child(_disposition_status)
    _disposition_option.item_selected.connect(func(_i: int) -> void: _disposition_confirm.disabled = _disposition_option.selected < 0)
    _disposition_confirm.pressed.connect(func() -> void:
        if _disposition_option.selected >= 0:
            disposition_submitted.emit(str(_disposition_option.get_item_metadata(_disposition_option.selected))))

func _send_assistant() -> void:
    if _assistant_sending or _assistant_input == null:
        return
    var text := _assistant_input.text.strip_edges()
    if text.is_empty():
        return
    _assistant_input.text = ""
    _assistant_say("You", text, INK)
    _assistant_history.append({"role": "user", "content": text})
    _assistant_sending = true
    _assistant_send.disabled = true
    _assistant_say("Codex", "…", MUTED)
    var payload := {"messages": _assistant_history, "task": _assistant_context()}
    var headers := PackedStringArray(["Content-Type: application/json"])
    var err := _assistant_http.request(assistant_proxy_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        _finish_assistant("(The copilot is offline — try the request trace on the Evidence tab and the code on Files & Tests.)")

func _on_assistant_response(_result: int, code: int, _headers: PackedStringArray, resp: PackedByteArray) -> void:
    if not _assistant_sending:
        return
    var reply := ""
    if code == 200:
        var parsed: Variant = JSON.parse_string(resp.get_string_from_utf8())
        if parsed is Dictionary:
            reply = str(parsed.get("reply", ""))
    _finish_assistant(reply if not reply.is_empty() else "(The copilot is offline — try the request trace on the Evidence tab and the code on Files & Tests.)")

func _finish_assistant(reply: String) -> void:
    _assistant_history.append({"role": "assistant", "content": reply})
    _assistant_sending = false
    if _assistant_send != null:
        _assistant_send.disabled = false
    if _assistant_log != null:
        var lines := _assistant_log.text.split("\n", false)
        if lines.size() > 0 and lines[lines.size() - 1].contains("…"):
            lines.remove_at(lines.size() - 1)
        _assistant_log.text = "\n".join(lines) + ("\n" if lines.size() > 0 else "")
    _assistant_say("Codex", reply, ACCENT["assistant"])

func _assistant_context() -> String:
    var parts := PackedStringArray([str(_scenario.get("brief", ""))])
    var orchestrator := _lookup(_scenario.get("artifacts", []), "artifact_id", "homepage_orchestrator")
    if not orchestrator.is_empty():
        parts.append("src/watch_page_orchestrator.ts:")
        for line: Variant in orchestrator.get("content", []):
            parts.append(str(line))
    return "\n".join(parts)

func _assistant_say(speaker: String, text: String, color: Color) -> void:
    if _assistant_log == null:
        return
    _assistant_log.text += "[color=#%s][b]%s[/b][/color]  %s\n" % [color.to_html(false), speaker, text]

## A dark, IDE-style read-out of the orchestrator source so prompt and code sit together.
func _add_code_panel(parent: Control) -> void:
    var orchestrator := _lookup(_scenario.get("artifacts", []), "artifact_id", "homepage_orchestrator")
    if orchestrator.is_empty():
        return
    var panel := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.09, 0.11, 0.16, 1)
    sb.border_color = Color(0.22, 0.5, 0.55, 0.6)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 14
    sb.content_margin_top = 10
    sb.content_margin_right = 14
    sb.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", sb)
    parent.add_child(panel)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 3)
    panel.add_child(col)
    var header := Label.new()
    header.text = "src/watch_page_orchestrator.ts"
    header.add_theme_color_override("font_color", Color(0.5, 0.82, 0.88, 1))
    header.add_theme_font_size_override("font_size", 13)
    col.add_child(header)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 168)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    col.add_child(scroll)
    var code := VBoxContainer.new()
    code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    code.add_theme_constant_override("separation", 0)
    scroll.add_child(code)
    var n := 1
    for line: Variant in orchestrator.get("content", []):
        var row := Label.new()
        row.text = "%2d  %s" % [n, str(line)]
        row.add_theme_color_override("font_color", Color(0.8, 0.86, 0.92, 1))
        row.add_theme_font_size_override("font_size", 13)
        code.add_child(row)
        n += 1

func _refresh_assistant(snapshot: Dictionary) -> void:
    if _disposition_status == null:
        return
    var disposition_id := str(snapshot.get("ai_disposition_id", ""))
    _disposition_status.text = "" if disposition_id.is_empty() else "Recorded your disposition: %s." % _humanize(disposition_id)

# --- Files & Tests -----------------------------------------------------------

func _build_tests_page() -> void:
    var body := _page_body("tests")
    body.add_child(_heading("Files & Tests", 27, INK))
    # Seeded workspace file: the faulty homepage orchestrator the candidate is debugging.
    var orchestrator := _lookup(_scenario.get("artifacts", []), "artifact_id", "homepage_orchestrator")
    if not orchestrator.is_empty():
        body.add_child(_heading("📄  src/watch_page_orchestrator.ts", 16, INK))
        var code_panel := PanelContainer.new()
        var code_style := StyleBoxFlat.new()
        code_style.bg_color = Color(0.16, 0.18, 0.26, 1)
        code_style.set_corner_radius_all(8)
        code_style.set_content_margin_all(14)
        code_panel.add_theme_stylebox_override("panel", code_style)
        var code := Label.new()
        code.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82, 1))
        code.add_theme_font_size_override("font_size", 14)
        var numbered := PackedStringArray()
        var line_no := 1
        for line: Variant in orchestrator.get("content", []):
            numbered.append("%2d   %s" % [line_no, str(line)])
            line_no += 1
        code.text = "\n".join(numbered)
        code_panel.add_child(code)
        body.add_child(code_panel)
        body.add_child(_heading("The watch-page lookups run one after another (await … await …). Read the trace on the Evidence tab.", 13, MUTED))
        body.add_child(HSeparator.new())
    body.add_child(_heading("Validation tests — run against a remediation to see the scripted result.", 15, MUTED))
    body.add_child(_heading("Remediation to validate", 15, INK))
    _tests_remediation = _option(_scenario.get("submission_options", {}).get("remediations", []), "option_id", "label")
    body.add_child(_tests_remediation)
    body.add_child(HSeparator.new())
    _test_result_labels.clear()
    for test: Dictionary in _scenario.get("tests", []):
        var test_id := str(test.get("test_id", ""))
        var card := VBoxContainer.new()
        card.add_theme_constant_override("separation", 4)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.add_child(_heading(str(test.get("title", test_id)), 16, INK))
        info.add_child(_heading(str(test.get("expected_result", "")), 13, MUTED))
        row.add_child(info)
        var run := _flat_button("Run test")
        run.custom_minimum_size = Vector2(120, 40)
        row.add_child(run)
        card.add_child(row)
        var result := _heading("", 14, ACCENT["tests"])
        card.add_child(result)
        body.add_child(card)
        body.add_child(HSeparator.new())
        _test_result_labels[test_id] = result
        run.pressed.connect(func() -> void:
            if _tests_remediation.selected < 0:
                result.text = "Choose a remediation to validate first."
                return
            verification_requested.emit(test_id, str(_tests_remediation.get_item_metadata(_tests_remediation.selected))))

func _refresh_tests(snapshot: Dictionary) -> void:
    if _test_result_labels.is_empty():
        return
    var latest: Dictionary = {}
    for action: Dictionary in snapshot.get("verification_actions", []):
        latest[str(action.get("test_id", ""))] = action
    for test_id: String in _test_result_labels:
        var label: Label = _test_result_labels[test_id]
        if latest.has(test_id):
            var displayed: Dictionary = latest[test_id].get("displayed_result", {})
            label.text = "✓ %s — %s" % [latest[test_id].get("remediation_id", ""), displayed.get("actual_result", "recorded")]
        else:
            label.text = ""

# --- Submit ------------------------------------------------------------------

func _build_submit_page() -> void:
    var body := _page_body("submit")
    var options: Dictionary = _scenario.get("submission_options", {})
    body.add_child(_heading("Revise your hypothesis (optional)", 20, INK))
    _revise_current = _heading("Current hypothesis: not recorded", 14, MUTED)
    body.add_child(_revise_current)
    _revise_option = _option(_scenario.get("hypotheses", []), "hypothesis_id", "label")
    body.add_child(_revise_option)
    _revise_confidence = _slider()
    body.add_child(_revise_confidence)
    _revise_confidence_label = _heading("Confidence: 50%", 14, INK)
    body.add_child(_revise_confidence_label)
    body.add_child(_heading("Trigger facts (from evidence you viewed):", 13, MUTED))
    _revise_facts = _itemlist(120)
    body.add_child(_revise_facts)
    _revise_button = _flat_button("Update hypothesis")
    _revise_button.disabled = true
    body.add_child(_revise_button)
    body.add_child(HSeparator.new())

    body.add_child(_heading("Submit your conclusion", 22, INK))
    _submit_root = _option(options.get("root_causes", []), "option_id", "label")
    body.add_child(_labeled("Root cause", _submit_root))
    _submit_remediation = _option(options.get("remediations", []), "option_id", "label")
    body.add_child(_labeled("Remediation", _submit_remediation))
    _submit_rollback = _option(options.get("rollbacks", []), "option_id", "label")
    body.add_child(_labeled("Rollback plan", _submit_rollback))
    _submit_validation = _itemlist(90)
    _fill_itemlist(_submit_validation, _scenario.get("tests", []), "test_id", "title")
    body.add_child(_labeled("Validation tests (select the ones you ran)", _submit_validation))
    _submit_evidence = _itemlist(90)
    body.add_child(_labeled("Supporting evidence (viewed artifacts)", _submit_evidence))
    _submit_risks = _itemlist(90)
    _fill_itemlist(_submit_risks, options.get("risks", []), "option_id", "label")
    body.add_child(_labeled("Risks", _submit_risks))
    _submit_assumptions = _itemlist(90)
    _fill_itemlist(_submit_assumptions, options.get("assumptions", []), "option_id", "label")
    body.add_child(_labeled("Assumptions", _submit_assumptions))
    _submit_confidence = _slider()
    body.add_child(_submit_confidence)
    _submit_confidence_label = _heading("Final confidence: 50%", 14, INK)
    body.add_child(_submit_confidence_label)
    _submit_rationale = TextEdit.new()
    _submit_rationale.custom_minimum_size = Vector2(0, 80)
    _submit_rationale.placeholder_text = "Explain your reasoning…"
    body.add_child(_labeled("Rationale", _submit_rationale))
    _submit_button = _flat_button("Submit conclusion")
    _submit_button.disabled = true
    body.add_child(_submit_button)
    _submit_status = _heading("", 14, ACCENT["submit"])
    _submit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(_submit_status)

    _revise_confidence.value_changed.connect(func(v: float) -> void: _revise_confidence_label.text = "Confidence: %d%%" % int(v))
    _revise_option.item_selected.connect(func(_i: int) -> void: _revise_button.disabled = _revise_option.selected < 0)
    _revise_button.pressed.connect(_on_revise)
    _submit_confidence.value_changed.connect(func(v: float) -> void: _submit_confidence_label.text = "Final confidence: %d%%" % int(v))
    for control: OptionButton in [_submit_root, _submit_remediation, _submit_rollback]:
        control.item_selected.connect(func(_i: int) -> void: _update_submit_state())
    _submit_validation.multi_selected.connect(func(_i: int, _s: bool) -> void: _update_submit_state())
    _submit_button.pressed.connect(_on_submit)

func _on_revise() -> void:
    if _revise_option.selected < 0:
        return
    revision_submitted.emit(
        str(_revise_option.get_item_metadata(_revise_option.selected)),
        int(_revise_confidence.value),
        _selected_metadata(_revise_facts))

func set_submit_error(errors: Array) -> void:
    if _submit_status != null:
        _submit_status.text = str(errors[0]) if not errors.is_empty() else ""

func _on_submit() -> void:
    if _submit_button.disabled:
        return
    if _submit_status != null:
        _submit_status.text = ""
    final_submission_requested.emit({
        "root_cause_id": _submit_root.get_item_metadata(_submit_root.selected),
        "evidence_ids": _selected_metadata(_submit_evidence),
        "remediation_id": _submit_remediation.get_item_metadata(_submit_remediation.selected),
        "risk_ids": _selected_metadata(_submit_risks),
        "assumption_ids": _selected_metadata(_submit_assumptions),
        "validation_test_ids": _selected_metadata(_submit_validation),
        "rollback_id": _submit_rollback.get_item_metadata(_submit_rollback.selected),
        "final_confidence": int(_submit_confidence.value),
        "rationale": _submit_rationale.text,
    })

func _update_submit_state() -> void:
    _submit_button.disabled = (
        _submit_root.selected < 0
        or _submit_remediation.selected < 0
        or _submit_rollback.selected < 0
        or _submit_validation.get_selected_items().is_empty())

func _refresh_submit(snapshot: Dictionary) -> void:
    if _revise_current == null:
        return
    var current: Dictionary = snapshot.get("current_hypothesis", {})
    _revise_current.text = "Current hypothesis: %s" % _hypothesis_label(str(current.get("hypothesis_id", "not recorded")))
    var viewed: Array = snapshot.get("viewed_artifact_ids", [])
    # Rebuild the lists to reflect newly-viewed evidence, but keep the candidate's
    # existing selection so an unrelated refresh never silently drops their input.
    var kept_facts := _selected_metadata(_revise_facts)
    _revise_facts.clear()
    for artifact: Dictionary in _scenario.get("artifacts", []):
        if not viewed.has(str(artifact.get("artifact_id", ""))):
            continue
        for fact: Dictionary in artifact.get("facts", []):
            _revise_facts.add_item(str(fact.get("label", fact.get("fact_id", ""))))
            _revise_facts.set_item_metadata(_revise_facts.item_count - 1, fact.get("fact_id", ""))
    _reselect(_revise_facts, kept_facts)
    var kept_evidence := _selected_metadata(_submit_evidence)
    _submit_evidence.clear()
    for artifact_id: Variant in viewed:
        var artifact := _lookup(_scenario.get("artifacts", []), "artifact_id", str(artifact_id))
        _submit_evidence.add_item(str(artifact.get("title", artifact_id)))
        _submit_evidence.set_item_metadata(_submit_evidence.item_count - 1, artifact_id)
    _reselect(_submit_evidence, kept_evidence)

# --- Report ------------------------------------------------------------------

func _build_report_page() -> void:
    var body := _page_body("report")
    _report_heading = _heading("Unscored prototype summary", 27, INK)
    body.add_child(_report_heading)
    _report_status = _heading("", 15, ACCENT["report"])
    body.add_child(_report_status)
    _report_score = _richtext("", 120)
    body.add_child(_report_score)
    _report_details = _richtext("", 200)
    body.add_child(_report_details)
    body.add_child(HSeparator.new())
    _report_notices = _richtext("", 120)
    body.add_child(_report_notices)
    var restart := _flat_button("Start another session")
    body.add_child(restart)
    restart.pressed.connect(func() -> void: restart_requested.emit())

func _populate_report(summary: Dictionary) -> void:
    _report_heading.text = str(summary.get("label", "Unscored prototype summary"))
    var status := "%s • %s" % [
        "Session complete" if summary.get("completed", false) else "Session in progress",
        "Saved locally" if summary.get("saved_to_disk", false) else "In-memory only",
    ]
    if not str(summary.get("persistence_warning", "")).is_empty():
        status += "\n%s" % summary.persistence_warning
    _report_status.text = status
    var submission: Dictionary = summary.get("final_submission", {})
    var lines := PackedStringArray([
        "Initial hypothesis: %s" % summary.get("initial_hypothesis", {}).get("label", "Not recorded"),
        "Final hypothesis: %s" % summary.get("final_hypothesis", {}).get("label", "Not recorded"),
        "Evidence views: %d" % summary.get("evidence_timeline", []).size(),
        "Verification actions: %d" % summary.get("verification_actions", []).size(),
    ])
    if not submission.is_empty():
        lines.append("Root cause: %s" % submission.get("root_cause", {}).get("label", "Not recorded"))
        lines.append("Remediation: %s" % submission.get("remediation", {}).get("label", "Not recorded"))
        lines.append("Rollback: %s" % submission.get("rollback", {}).get("label", "Not recorded"))
        lines.append("Rationale: %s" % submission.get("rationale", ""))
    _report_details.text = "\n".join(lines)
    var notices: Dictionary = summary.get("notices", {})
    _report_notices.text = "%s\n\n%s\n\n%s" % [notices.get("human_review", ""), notices.get("limitations", ""), notices.get("navigation", "")]

# --- Widget helpers ----------------------------------------------------------

func _heading(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _richtext(text: String, min_height: int) -> RichTextLabel:
    var rt := RichTextLabel.new()
    rt.bbcode_enabled = true
    rt.fit_content = true
    rt.custom_minimum_size = Vector2(0, min_height)
    rt.add_theme_color_override("default_color", INK)
    rt.text = text
    return rt

func _slider() -> HSlider:
    var slider := HSlider.new()
    slider.min_value = 0
    slider.max_value = 100
    slider.value = 50
    slider.focus_mode = Control.FOCUS_ALL
    return slider

func _option(items: Variant, id_field: String, label_field: String, humanize := false) -> OptionButton:
    var control := OptionButton.new()
    control.focus_mode = Control.FOCUS_ALL
    for item: Dictionary in items if typeof(items) == TYPE_ARRAY else []:
        var text := str(item.get(label_field, item.get(id_field, "")))
        control.add_item(_humanize(text) if humanize else text)
        control.set_item_metadata(control.item_count - 1, item.get(id_field, ""))
    control.select(-1)
    return control

func _itemlist(min_height: int) -> ItemList:
    var list := ItemList.new()
    list.select_mode = ItemList.SELECT_MULTI
    list.custom_minimum_size = Vector2(0, min_height)
    list.focus_mode = Control.FOCUS_ALL
    list.add_theme_color_override("font_color", INK)
    return list

func _fill_itemlist(list: ItemList, items: Variant, id_field: String, label_field: String) -> void:
    list.clear()
    for item: Dictionary in items if typeof(items) == TYPE_ARRAY else []:
        list.add_item(str(item.get(label_field, item.get(id_field, ""))))
        list.set_item_metadata(list.item_count - 1, item.get(id_field, ""))

func _labeled(label: String, control: Control) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    box.add_child(_heading(label, 14, INK))
    box.add_child(control)
    return box

func _bubble(speaker: String, text: String, bg: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.set_corner_radius_all(10)
    style.set_content_margin_all(12)
    panel.add_theme_stylebox_override("panel", style)
    var col := VBoxContainer.new()
    col.add_child(_heading(speaker, 13, MUTED))
    col.add_child(_heading(text, 15, INK))
    panel.add_child(col)
    return panel

func _card_button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.focus_mode = Control.FOCUS_ALL
    button.custom_minimum_size = Vector2(0, 44)
    button.add_theme_font_size_override("font_size", 15)
    var style := StyleBoxFlat.new()
    style.bg_color = CARD
    style.set_corner_radius_all(8)
    style.set_border_width_all(1)
    style.border_color = CARD_BORDER
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_color_override("font_color", INK)
    return button

func _add_workspace_card(parent: Container, title: String, accent: Color) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(250, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = CARD
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = CARD_BORDER
    style.border_width_top = 4
    style.border_color = accent
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 14
    style.content_margin_bottom = 16
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 9)
    panel.add_child(content)
    content.add_child(_heading(title, 14, accent))
    return content

func _add_scrollable_workspace_card(parent: Container, title: String, accent: Color) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = CARD
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = accent
    style.border_width_top = 4
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var margins := MarginContainer.new()
    margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margins.add_theme_constant_override("margin_left", 16)
    margins.add_theme_constant_override("margin_right", 16)
    margins.add_theme_constant_override("margin_top", 14)
    margins.add_theme_constant_override("margin_bottom", 16)
    scroll.add_child(margins)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 9)
    margins.add_child(content)
    content.add_child(_heading(title, 14, accent))
    return content

func _flat_button(text: String) -> Button:
    var button := _card_button(text)
    button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    return button

func _selected_metadata(list: ItemList) -> Array:
    var ids: Array = []
    for index: int in list.get_selected_items():
        ids.append(list.get_item_metadata(index))
    return ids

func _reselect(list: ItemList, kept: Array) -> void:
    for index: int in range(list.item_count):
        if kept.has(list.get_item_metadata(index)):
            list.select(index, false)

func _hypothesis_label(hypothesis_id: String) -> String:
    return str(_lookup(_scenario.get("hypotheses", []), "hypothesis_id", hypothesis_id).get("label", hypothesis_id))

func _lookup(items: Variant, field: String, requested_id: String) -> Dictionary:
    for item: Variant in items if typeof(items) == TYPE_ARRAY else []:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(field, "")) == requested_id:
            return item
    return {}

func _humanize(value: String) -> String:
    return value.replace("_", " ").capitalize()

func _apply_page_theme() -> void:
    var t := Theme.new()
    t.set_color("font_color", "Label", INK)
    t.set_color("default_color", "RichTextLabel", INK)
    t.set_color("font_color", "Button", INK)
    t.set_color("font_color", "OptionButton", INK)
    var card := StyleBoxFlat.new()
    card.bg_color = CARD
    card.set_corner_radius_all(12)
    card.set_content_margin_all(6)
    t.set_stylebox("panel", "PanelContainer", card)
    var field := StyleBoxFlat.new()
    field.bg_color = Color(1, 0.99, 0.97, 1)
    field.set_corner_radius_all(6)
    field.set_border_width_all(1)
    field.border_color = CARD_BORDER
    field.set_content_margin_all(6)
    t.set_stylebox("normal", "TextEdit", field)
    t.set_color("font_color", "TextEdit", INK)
    t.set_stylebox("panel", "ItemList", field)
    t.set_color("font_color", "ItemList", INK)
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
        box.border_color = CARD_BORDER
        t.set_stylebox(state, "Button", box)
        t.set_stylebox(state, "OptionButton", box)
    theme = t
