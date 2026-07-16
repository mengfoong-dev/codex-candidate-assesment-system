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
    "brief": Color(0.98, 0.7, 0.25, 1),
    "evidence": Color(0.1, 0.78, 0.95, 1),
    "assistant": Color(0.66, 0.42, 0.94, 1),
    "tests": Color(0.24, 0.82, 0.49, 1),
    "submit": Color(0.95, 0.45, 0.55, 1),
    "report": Color(0.98, 0.7, 0.25, 1),
}
const TAB_DEFS := [
    {"key": "brief", "label": "Brief"},
    {"key": "prompting", "label": "Candidate Prompting"},
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
var _report_details: RichTextLabel
var _report_notices: RichTextLabel

func _ready() -> void:
    _apply_page_theme()
    _assistant_http = HTTPRequest.new()
    add_child(_assistant_http)
    _assistant_http.request_completed.connect(_on_assistant_response)
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
    if key != "brief" and key != "report" and not _started:
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
        var locked := (key != "brief" and key != "report" and not _started) or (key == "report" and not _report_available)
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

# --- Brief -------------------------------------------------------------------

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
    var body := _page_body("prompting")
    body.add_child(_heading("Candidate Prompting", 27, INK))
    body.add_child(_heading("Use the copilot alongside the evidence workspace. Your prompts and actions are recorded.", 15, MUTED))

    var workspace := HBoxContainer.new()
    workspace.add_theme_constant_override("separation", 14)
    workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(workspace)

    var incident_card := _add_workspace_card(workspace, "Incident brief", ACCENT["brief"])
    incident_card.add_child(_heading("%s — %s" % [_scenario.get("title", "Incident briefing"), _scenario.get("role", "Candidate")], 18, INK))
    incident_card.add_child(_richtext(str(_scenario.get("brief", "")), 130))
    incident_card.add_child(HSeparator.new())
    incident_card.add_child(_heading("Assessment flow", 15, ACCENT["brief"]))
    incident_card.add_child(_heading("Your initial hypothesis is recorded. Use this screen to investigate it with the copilot and the evidence below.", 14, MUTED))

    var conversation_card := _add_workspace_card(workspace, "Conversation", ACCENT["assistant"])
    conversation_card.add_child(_heading("Engineering copilot", 18, INK))
    conversation_card.add_child(_heading("Copilot ready · prompts stay in this assessment session.", 13, MUTED))
    var chat_scroll := ScrollContainer.new()
    chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    chat_scroll.custom_minimum_size = Vector2(0, 255)
    conversation_card.add_child(chat_scroll)
    var chat_log := VBoxContainer.new()
    chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_log.add_theme_constant_override("separation", 8)
    chat_scroll.add_child(chat_log)
    chat_log.add_child(_bubble("You", "Help me understand the latency spike and what I should verify first.", Color(0.88, 0.91, 0.98, 1)))
    chat_log.add_child(_bubble("Copilot", "Start with the trace and compare it with healthy CPU and database signals. Then inspect the homepage orchestration code.", Color(0.93, 0.88, 0.99, 1)))
    var chat_row := HBoxContainer.new()
    chat_row.add_theme_constant_override("separation", 7)
    conversation_card.add_child(chat_row)
    var chat_input := LineEdit.new()
    chat_input.placeholder_text = "Ask the copilot about this incident"
    chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_input.add_theme_font_size_override("font_size", 14)
    chat_row.add_child(chat_input)
    var chat_send := _flat_button("Send")
    chat_send.custom_minimum_size = Vector2(74, 38)
    chat_row.add_child(chat_send)
    var send_prompt := func() -> void:
        var prompt := chat_input.text.strip_edges()
        if prompt.is_empty():
            return
        chat_log.add_child(_bubble("You", prompt, Color(0.88, 0.91, 0.98, 1)))
        chat_input.clear()
        chat_log.add_child(_bubble("Copilot", "Focus on the trace, compare it with the healthy service signals, and use the artifacts on the right to validate your hypothesis.", Color(0.93, 0.88, 0.99, 1)))
        chat_scroll.scroll_vertical = 100000
    chat_send.pressed.connect(send_prompt)
    chat_input.text_submitted.connect(func(_text: String) -> void: send_prompt.call())

    var output_card := _add_workspace_card(workspace, "Evidence and output", ACCENT["evidence"])
    output_card.add_child(_heading("Homepage signals", 18, INK))
    output_card.add_child(_heading("p95 latency   180 ms → 850 ms\nCPU usage     35% (healthy)\nDatabase      healthy", 15, INK))
    output_card.add_child(HSeparator.new())
    output_card.add_child(_heading("Evidence", 15, ACCENT["evidence"]))
    var evidence_scroll := ScrollContainer.new()
    evidence_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    evidence_scroll.custom_minimum_size = Vector2(0, 170)
    output_card.add_child(evidence_scroll)
    var evidence_list := VBoxContainer.new()
    evidence_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    evidence_list.add_theme_constant_override("separation", 7)
    evidence_scroll.add_child(evidence_list)
    for artifact: Dictionary in _scenario.get("artifacts", []):
        evidence_list.add_child(_heading(str(artifact.get("title", "Evidence artifact")), 14, INK))
        var content: Array = artifact.get("content", [])
        if not content.is_empty():
            evidence_list.add_child(_heading("• " + str(content[0]), 13, MUTED))
    output_card.add_child(HSeparator.new())
    output_card.add_child(_heading("Result", 15, ACCENT["submit"]))
    output_card.add_child(_heading("Build an evidence-backed diagnosis, then state a safe remediation, validation plan, and rollback condition in your submission.", 14, MUTED))

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
    body.add_child(_heading("AI Assistant", 27, INK))
    body.add_child(_heading("Live copilot — recorded. It reasons about the code/evidence; it won't hand you the answer.", 14, MUTED))
    _assistant_log = RichTextLabel.new()
    _assistant_log.bbcode_enabled = true
    _assistant_log.fit_content = true
    _assistant_log.scroll_active = true
    _assistant_log.custom_minimum_size = Vector2(0, 240)
    _assistant_log.add_theme_color_override("default_color", INK)
    body.add_child(_assistant_log)
    _assistant_history.clear()
    _assistant_say("Assistant", "Hi — I'm your workspace copilot. Ask me about the trace, the logs, or the orchestrator code and I'll help you reason it through.", ACCENT["assistant"])
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    body.add_child(row)
    _assistant_input = LineEdit.new()
    _assistant_input.placeholder_text = "Ask the assistant about the incident or the code…"
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
    _assistant_say("Assistant", "…", MUTED)
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
    _assistant_say("Assistant", reply, ACCENT["assistant"])

func _assistant_context() -> String:
    var parts := PackedStringArray([str(_scenario.get("brief", ""))])
    var orchestrator := _lookup(_scenario.get("artifacts", []), "artifact_id", "homepage_orchestrator")
    if not orchestrator.is_empty():
        parts.append("src/homepage_orchestrator.ts:")
        for line: Variant in orchestrator.get("content", []):
            parts.append(str(line))
    return "\n".join(parts)

func _assistant_say(speaker: String, text: String, color: Color) -> void:
    if _assistant_log == null:
        return
    _assistant_log.text += "[color=#%s][b]%s[/b][/color]  %s\n" % [color.to_html(false), speaker, text]

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
        body.add_child(_heading("📄  src/homepage_orchestrator.ts", 16, INK))
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
        body.add_child(_heading("The homepage lookups run one after another (await … await …). Read the trace on the Evidence tab.", 13, MUTED))
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
