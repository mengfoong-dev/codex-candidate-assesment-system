class_name IDEConsole
extends Control

## In-game "Codex" IDE: a Claude-style split workspace with prompting on the left and
## editable incident source on the right. The candidate asks "Codex" (the senior-proxy assistant)
## to change it; a fenced ```code``` block in the reply is applied straight into the editor.
##
## Self-contained by design: owns its own show/hide (backtick or the Close button), pauses the
## tree while open, and needs no coordinator/main.gd state. Wired into main.tscn as one UI node.
##
## ponytail: uses the buffered senior-proxy assistant (HTTPRequest), NOT the backend agentic SSE
## stream. Godot's Web export does not reliably stream HTTPClient bodies, and the assistant route
## already returns a full reply with a fenced updated file — same "Codex edits your code" result,
## web-safe. Upgrade path: swap _submit()/_on_reply() for an HTTPClient SSE pump against
## backend_base_url + POST /api/sessions/{id}/messages when a desktop build needs live streaming.

## Emitted with the candidate's raw prompt each time they ask Codex — logged for Layer-2 review.
signal prompt_submitted(text: String)
## Emitted with the full edited file content whenever an assistant reply applies a code change, so
## the candidate's AI-edited orchestrator can be streamed to the backend for content-aware grading.
signal code_applied(content: String)

## Live in-workspace copilot endpoint (the senior-proxy assistant route).
@export var assistant_proxy_url := "https://senior-proxy-production-82cf.up.railway.app/api/assistant/chat"
## Sandboxed test runner (hauxuen's Docker proxy). Grades the candidate's code for real.
@export var test_runner_url := "https://proxy.leehaoxuen.com/api/assistant/test"
## Kept for the future agentic-SSE upgrade above; unused on the web target today.
@export var backend_base_url := "https://vibeproof-backend-production.up.railway.app"

const SCENARIO_PATH := "res://data/scenarios/homepage_latency_v1.json"
const FONT_PATH := "res://assets/third_party/fonts/JetBrainsMono-Regular.ttf"
const SOURCE_ARTIFACT := "homepage_orchestrator"  # scenario artifact_id (internal, unchanged)
const EDITOR_TAB := "src/watch_page_orchestrator.ts"

# VS Code Dark+ palette.
const BG := Color("1e1e1e")
const PANEL := Color("181818")
const FG := Color("d4d4d4")
const MUTED := Color("858585")
const GREEN := Color("6a9955")
const TEAL := Color("4ec9b0")
const AMBER := Color("dcdcaa")

@onready var _body: Control = $Body
@onready var _hint: Label = $Hint
@onready var _split: HSplitContainer = $Body/Margin/Rows/Split
@onready var _brand: Label = $Body/Margin/Rows/TitleBar/Brand
@onready var _title: Label = $Body/Margin/Rows/TitleBar/Title
@onready var _close: Button = $Body/Margin/Rows/TitleBar/Close
@onready var _file_path: Label = $Body/Margin/Rows/Split/Code/Header/FilePath
@onready var _file_rail: ItemList = $Body/Margin/Rows/Split/Code/Header/FileRail
@onready var _source_label: Label = $Body/Margin/Rows/Split/Code/Header/SourceLabel
@onready var _saved: Label = $Body/Margin/Rows/Split/Code/Header/Saved
@onready var _files_panel: PanelContainer = $Body/Margin/Rows/Split/Files
@onready var _file_list: ItemList = $Body/Margin/Rows/Split/Files/Column/FileList
@onready var _test_list: ItemList = $Body/Margin/Rows/Split/Files/Column/TestList
@onready var _run_tests: Button = $Body/Margin/Rows/Split/Code/Header/RunTests
@onready var _editor: CodeEdit = $Body/Margin/Rows/Split/Code/WorkArea/Editor
@onready var _terminal: PanelContainer = $Body/Margin/Rows/Split/Code/WorkArea/Terminal
@onready var _terminal_output: RichTextLabel = $Body/Margin/Rows/Split/Code/WorkArea/Terminal/Column/Output
@onready var _terminal_status: Label = $Body/Margin/Rows/Split/Code/WorkArea/Terminal/Column/Header/Status
@onready var _conversation: PanelContainer = $Body/Margin/Rows/Split/Conversation
@onready var _composer: PanelContainer = $Body/Margin/Rows/Split/Conversation/Column/Composer
@onready var _scroll: ScrollContainer = $Body/Margin/Rows/Split/Conversation/Column/Scroll
@onready var _messages: VBoxContainer = $Body/Margin/Rows/Split/Conversation/Column/Scroll/Messages
@onready var _input: TextEdit = $Body/Margin/Rows/Split/Conversation/Column/Composer/Column/PromptRow/Input
@onready var _send: Button = $Body/Margin/Rows/Split/Conversation/Column/Composer/Column/PromptRow/Send

var _http: HTTPRequest
var _files := {}          # path -> source text
var _brief := ""
var _history: Array = []  # [{role, content}] sent to the assistant
var _lines: Array = []    # conversation transcript (bbcode lines)
var _terminal_lines: Array = []
var _active_path := EDITOR_TAB
var _thinking_card: Control
var _busy := false
var _request_kind := "chat"  # "chat" | "test" — routes the shared _http reply in _on_reply
var _paused_by_us := false

func _ready() -> void:
	# Runtime order is intentional: Files | Copilot conversation | source and terminal.
	_split.move_child(_conversation, 1)
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_reply)
	_apply_theme()
	_close.pressed.connect(hide_console)
	_input.gui_input.connect(_on_prompt_input)
	_send.pressed.connect(func() -> void: _on_submit(_input.text))
	_file_list.item_selected.connect(_on_file_selected)
	_test_list.item_selected.connect(_on_test_selected)
	_run_tests.pressed.connect(_on_run_tests)
	_seed_from_scenario()
	_hint.visible = false  # PC-only now: opened from the workspace, not a floating backtick hint
	_terminal_log("[color=#8b949e]Workspace ready. Ask Copilot for a change, then run tests to validate it.[/color]")

## Clear every per-candidate trace (chat history, terminal scrollback, edited source) so the
## next session starts clean. Called by main.restart_session — the console is a persistent scene
## node, so without this the previous candidate's Codex conversation + edits bleed through.
func reset() -> void:
	_history.clear()
	_lines.clear()
	_terminal_lines.clear()
	for card in _messages.get_children():
		card.queue_free()
	_thinking_card = null
	_busy = false
	_request_kind = "chat"
	if is_instance_valid(_input):
		_input.editable = true
		_input.clear()
	if is_instance_valid(_send):
		_send.disabled = false
	if is_instance_valid(_run_tests):
		_run_tests.disabled = false
	_seed_from_scenario()  # re-reads pristine source into the editor
	_terminal_status.text = "Ready"
	_terminal_log("[color=#8b949e]Workspace ready. Ask Copilot for a change, then run tests to validate it.[/color]")
	hide_console()

# --- show / hide ---------------------------------------------------------

## PC-only: the console opens from the workspace's Codex tab (main._open_codex_console),
## never a global hotkey — so it can't bypass the investigate-first gate. Backtick only
## closes it while open, as a convenience.
func _unhandled_input(event: InputEvent) -> void:
	if _body.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		hide_console()
		get_viewport().set_input_as_handled()

## Don't open (and pause the tree) while the entry/sign-in screen is up. Read-only sibling
## lookup so this stays decoupled from the (concurrently edited) title screen script.
func _can_open() -> bool:
	var parent := get_parent()
	var title := parent.get_node_or_null("TitleScreen") if parent != null else null
	return not (title is CanvasItem and title.visible)

func show_console() -> void:
	_body.visible = true
	_hint.visible = false
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	_input.grab_focus.call_deferred()

func hide_console() -> void:
	_body.visible = false
	_hint.visible = false
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false

# --- theme ---------------------------------------------------------------

func _apply_theme() -> void:
	var mono: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var editor_box := _flat(BG, 18, 16)
	editor_box.border_color = Color("30363d")
	editor_box.set_border_width_all(1)
	_editor.add_theme_stylebox_override("normal", editor_box)
	_editor.add_theme_stylebox_override("focus", editor_box)
	_editor.add_theme_stylebox_override("read_only", editor_box)
	_editor.add_theme_color_override("font_color", FG)
	_editor.add_theme_color_override("font_readonly_color", FG)
	_editor.add_theme_color_override("line_number_color", MUTED)
	_editor.add_theme_color_override("current_line_color", Color(0.165, 0.176, 0.184, 0.65))
	_editor.add_theme_color_override("caret_color", Color("aeafad"))
	_editor.add_theme_font_size_override("font_size", 15)
	_editor.syntax_highlighter = _ts_highlighter()
	var conversation_box := _flat(Color("111827"), 18, 16)
	conversation_box.border_color = Color("30363d")
	conversation_box.set_border_width_all(1)
	conversation_box.set_corner_radius_all(10)
	_conversation.add_theme_stylebox_override("panel", conversation_box)
	var composer_box := _flat(Color("0d1117"), 12, 10)
	composer_box.border_color = Color("30363d")
	composer_box.set_border_width_all(1)
	composer_box.set_corner_radius_all(8)
	_composer.add_theme_stylebox_override("panel", composer_box)
	var terminal_box := _flat(Color("0d1117"), 14, 10)
	terminal_box.border_color = Color("30363d")
	terminal_box.set_border_width_all(1)
	terminal_box.set_corner_radius_all(8)
	_terminal.add_theme_stylebox_override("panel", terminal_box)
	var files_box := _flat(Color("111827"), 14, 14)
	files_box.border_color = Color("30363d")
	files_box.set_border_width_all(1)
	files_box.set_corner_radius_all(10)
	_files_panel.add_theme_stylebox_override("panel", files_box)
	_terminal_output.add_theme_color_override("default_color", Color("8b949e"))
	_terminal_output.add_theme_font_size_override("normal_font_size", 13)
	_terminal_status.add_theme_color_override("font_color", Color("8b949e"))
	_run_tests.add_theme_stylebox_override("normal", _flat(Color("238636"), 10, 5))
	_run_tests.add_theme_stylebox_override("hover", _flat(Color("2ea043"), 10, 5))
	_run_tests.add_theme_color_override("font_color", Color("ffffff"))
	var selected_file := _flat(Color("1f6feb"), 8, 5)
	selected_file.set_corner_radius_all(5)
	var hover_file := _flat(Color("21262d"), 8, 5)
	for list in [_file_list, _test_list]:
		list.add_theme_color_override("font_color", Color("c9d1d9"))
		list.add_theme_color_override("font_selected_color", Color("ffffff"))
		list.add_theme_stylebox_override("selected", selected_file)
		list.add_theme_stylebox_override("hovered", hover_file)
	for label in [
		$Body/Margin/Rows/Split/Files/Column/Title,
		$Body/Margin/Rows/Split/Files/Column/SourceLabel,
		$Body/Margin/Rows/Split/Files/Column/TestsLabel,
	]:
		label.add_theme_color_override("font_color", Color("8b949e"))
		label.add_theme_font_size_override("font_size", 12)
	_brand.add_theme_color_override("font_color", Color("f0f6fc"))
	_brand.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color("8b949e"))
	_title.add_theme_font_size_override("font_size", 16)
	_source_label.add_theme_color_override("font_color", Color("8b949e"))
	_source_label.add_theme_font_size_override("font_size", 12)
	_file_path.add_theme_color_override("font_color", Color("f0f6fc"))
	_file_path.add_theme_font_size_override("font_size", 16)
	_saved.add_theme_color_override("font_color", Color("3fb950"))
	_hint.add_theme_color_override("font_color", Color("cccccc"))
	_hint.add_theme_stylebox_override("normal", _flat(Color(0.09, 0.09, 0.09, 0.85), 8, 4))
	var input_box := _flat(Color("161b22"), 14, 12)
	input_box.set_corner_radius_all(8)
	_input.add_theme_stylebox_override("normal", input_box)
	_input.add_theme_stylebox_override("focus", input_box)
	_input.add_theme_color_override("font_color", Color("f0f6fc"))
	_input.add_theme_color_override("font_placeholder_color", Color("7d8590"))
	var send_box := _flat(Color("238636"), 12, 8)
	send_box.set_corner_radius_all(6)
	_send.add_theme_stylebox_override("normal", send_box)
	_send.add_theme_stylebox_override("hover", _flat(Color("2ea043"), 12, 8))
	_send.add_theme_color_override("font_color", Color("ffffff"))
	var close_box := _flat(Color("b42318"), 12, 7)
	close_box.set_corner_radius_all(6)
	_close.add_theme_stylebox_override("normal", close_box)
	_close.add_theme_stylebox_override("hover", _flat(Color("dc2626"), 12, 7))
	_close.add_theme_color_override("font_color", Color("ffffff"))
	if mono != null:
		_editor.add_theme_font_override("font", mono)
		_terminal_output.add_theme_font_override("normal_font", mono)
		for c in [_title, _file_path, _input, _hint]:
			c.add_theme_font_override("font", mono)

func _flat(color: Color, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box

func _ts_highlighter() -> CodeHighlighter:
	var hl := CodeHighlighter.new()
	hl.number_color = Color("b5cea8")
	hl.symbol_color = Color("d4d4d4")
	hl.function_color = Color("dcdcaa")
	hl.member_variable_color = Color("9cdcfe")
	var kw := Color("569cd6")
	var ctl := Color("c586c0")
	for w in ["const", "let", "var", "function", "class", "interface", "type", "enum", "import",
			"export", "from", "new", "extends", "implements", "public", "private", "readonly",
			"void", "string", "number", "boolean", "Promise"]:
		hl.add_keyword_color(w, kw)
	for w in ["return", "await", "async", "if", "else", "for", "while", "try", "catch", "throw",
			"break", "continue"]:
		hl.add_keyword_color(w, ctl)
	var s := Color("ce9178")
	hl.add_color_region("\"", "\"", s)
	hl.add_color_region("'", "'", s)
	hl.add_color_region("`", "`", s)
	var c := Color("6a9955")
	hl.add_color_region("//", "", c, true)
	hl.add_color_region("/*", "*/", c, false)
	return hl

# --- editor seeding ------------------------------------------------------

func _seed_from_scenario() -> void:
	var res := ScenarioLoader.load_file(SCENARIO_PATH)
	var scenario: Dictionary = res.get("scenario", {})
	_brief = str(scenario.get("brief", ""))
	var art := _lookup(scenario.get("artifacts", []), "artifact_id", SOURCE_ARTIFACT)
	var lines := PackedStringArray()
	for l in art.get("content", []):
		lines.append(str(l))
	var src := "\n".join(lines)
	if src.strip_edges().is_empty():
		src = _fallback_source()
	_files.clear()
	_files[EDITOR_TAB] = src
	_files["tests/watch_page_orchestrator.test.ts"] = _test_file()
	_file_rail.clear()
	_file_rail.add_item(EDITOR_TAB)
	_file_list.clear()
	_file_list.add_item("watch_page_orchestrator.ts")
	_file_list.set_item_metadata(0, EDITOR_TAB)
	_test_list.clear()
	_test_list.add_item("watch_page_orchestrator.test.ts")
	_test_list.set_item_metadata(0, "tests/watch_page_orchestrator.test.ts")
	_file_list.select(0)
	_active_path = ""
	_show_file(EDITOR_TAB)

func _lookup(items: Variant, key: String, value: String) -> Dictionary:
	if items is Array:
		for it in items:
			if it is Dictionary and str(it.get(key, "")) == value:
				return it
	return {}

func _show_file(path: String) -> void:
	if _active_path == EDITOR_TAB:
		_files[EDITOR_TAB] = _editor.text
	_active_path = path
	_editor.text = str(_files.get(path, ""))
	_editor.editable = path == EDITOR_TAB
	_file_path.text = path
	_source_label.text = "SOURCE" if path == EDITOR_TAB else "TEST"

func _on_file_selected(index: int) -> void:
	if index >= 0:
		_test_list.deselect_all()
		_show_file(str(_file_list.get_item_metadata(index)))

func _on_test_selected(index: int) -> void:
	if index >= 0:
		_file_list.deselect_all()
		_show_file(str(_test_list.get_item_metadata(index)))

func _on_run_tests() -> void:
	if _busy:
		return
	if _active_path == EDITOR_TAB:
		_files[EDITOR_TAB] = _editor.text
	_busy = true
	_request_kind = "test"
	_send.disabled = true
	_run_tests.disabled = true
	_terminal_status.text = "Running"
	_terminal_log("[color=#8b949e]$ npm test -- watch_page_orchestrator[/color]")
	_terminal_log("[color=#79c0ff]›[/color] running isolated scenario tests in the sandbox…")
	var payload := {"code": str(_files.get(EDITOR_TAB, ""))}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(test_runner_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_apply_test_result({"status": "unavailable", "error": "could not reach the test runner"})

## Render a real sandbox test result into the terminal. Reached via _on_reply when
## _request_kind == "test" (the shared _http is also used by the chat assistant).
func _apply_test_result(result: Dictionary) -> void:
	_busy = false
	_request_kind = "chat"
	_send.disabled = false
	_run_tests.disabled = false
	if str(result.get("status", "unavailable")) == "unavailable":
		_terminal_status.text = "Error"
		_terminal_log("[color=#f85149]✗[/color] tests unavailable: %s" % _escape(str(result.get("error", "unknown error"))))
		return
	for test: Variant in result.get("tests", []):
		var row: Dictionary = test
		var passed := str(row.get("status", "")) == "passed"
		var line := "[color=%s]%s[/color] %s" % ["#3fb950" if passed else "#f85149", "✓" if passed else "✗", _escape(str(row.get("name", "test")))]
		var msg := str(row.get("message", ""))
		if not passed and not msg.is_empty():
			line += "  [color=#8b949e]%s[/color]" % _escape(msg.split("\n")[0])
		_terminal_log(line)
	var ok := str(result.get("status", "")) == "passed"
	_terminal_status.text = "Passed" if ok else "Needs changes"
	_terminal_log("[color=%s]%d passed, %d failed[/color]" % ["#3fb950" if ok else "#8b949e", int(result.get("passed", 0)), int(result.get("failed", 0))])

# --- prompt -> assistant -> apply ---------------------------------------

func _on_prompt_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and not event.shift_pressed:
		_on_submit(_input.text)
		_input.get_viewport().set_input_as_handled()

func _on_submit(text: String) -> void:
	var prompt := text.strip_edges()
	if prompt.is_empty() or _busy:
		return
	_input.clear()
	prompt_submitted.emit(prompt)
	_append_message_card("YOU", prompt, Color("152238"), Color("79c0ff"))
	_history.append({"role": "user", "content": prompt})
	_busy = true
	_input.editable = false
	_send.disabled = true
	_terminal_status.text = "Working"
	_terminal_log("[color=#79c0ff]›[/color] Codex request sent")
	_thinking_card = _append_message_card("CODEX", "Codex is thinking…", Color("251b3b"), Color("d2a8ff"), true)
	var payload := {"messages": _history, "task": _task_context()}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(assistant_proxy_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		apply_assistant_reply(_offline_reply())

func _task_context() -> String:
	return "\n".join(PackedStringArray([
		_brief,
		"The candidate is editing %s. Current contents:" % EDITOR_TAB,
		str(_files.get(EDITOR_TAB, _editor.text)),
		"When you change the code, reply with a one-line explanation then the FULL updated file in one ```ts fenced block.",
	]))

func _on_reply(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _busy:
		return
	if _request_kind == "test":
		var parsed_test: Variant = JSON.parse_string(body.get_string_from_utf8())
		if code == 200 and parsed_test is Dictionary:
			_apply_test_result(parsed_test)
		else:
			_apply_test_result({"status": "unavailable", "error": "test runner returned HTTP %d" % code})
		return
	var reply := ""
	if code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			reply = str(parsed.get("reply", ""))
	apply_assistant_reply(reply if not reply.is_empty() else _offline_reply())

## The one testable seam: given an assistant reply, log the prose and apply any fenced code block
## into the editor. Called by both the live response handler and the offline fallback.
func apply_assistant_reply(reply: String) -> void:
	_history.append({"role": "assistant", "content": reply})
	_remove_thinking()
	var prose := _strip_code(reply)
	_append_message_card("CODEX", prose if not prose.strip_edges().is_empty() else reply, Color("251b3b"), Color("d2a8ff"))
	var code := _extract_code(reply)
	if not code.is_empty():
		_files[EDITOR_TAB] = code
		_active_path = ""
		_show_file(EDITOR_TAB)
		_terminal_status.text = "Changed"
		_terminal_log("[color=#3fb950]✓[/color] Applied Codex change to %s" % EDITOR_TAB)
		code_applied.emit(code)
	else:
		_terminal_status.text = "Review"
		_terminal_log("[color=#8b949e]Codex reply received; no code change applied.[/color]")
	_busy = false
	_input.editable = true
	_send.disabled = false

# --- fenced-code helpers (reused from browser_workspace's proven parser) -

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

## Prose shown in the terminal = everything before the first fenced block.
func _strip_code(reply: String) -> String:
	var i := reply.find("```")
	return reply.substr(0, i).strip_edges() if i > 0 else reply

# --- conversation cards / terminal scrollback ---------------------------

func _append_message_card(sender: String, message: String, fill: Color, label_color: Color, thinking := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_box := _flat(fill, 14, 12)
	card_box.border_color = Color("30363d")
	card_box.set_border_width_all(1)
	card_box.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var sender_label := Label.new()
	sender_label.text = sender
	sender_label.add_theme_color_override("font_color", label_color)
	sender_label.add_theme_font_size_override("font_size", 12)
	column.add_child(sender_label)
	var body_label := Label.new()
	body_label.text = message
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", Color("f0f6fc") if not thinking else Color("a78bfa"))
	body_label.add_theme_font_size_override("font_size", 14)
	if ResourceLoader.exists(FONT_PATH):
		body_label.add_theme_font_override("font", load(FONT_PATH))
	column.add_child(body_label)
	_messages.add_child(card)
	_scroll.call_deferred("set_v_scroll", 1000000)
	return card

func _remove_thinking() -> void:
	if is_instance_valid(_thinking_card):
		_thinking_card.queue_free()
	_thinking_card = null

func _terminal_log(bbcode_line: String) -> void:
	_terminal_lines.append(bbcode_line)
	if is_instance_valid(_terminal_output):
		_terminal_output.text = "\n".join(_terminal_lines)

func _escape(s: String) -> String:
	return s.replace("[", "[lb]")

# --- offline fallbacks (no backend / proxy) ------------------------------

func _offline_reply() -> String:
	return "The three data fetches are independent, so I updated the source to run them together with Promise.all. Review the edit, then run the test suite.\n```ts\n%s\n```" % _reference_fix()

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

func _fallback_source() -> String:
	return "\n".join(PackedStringArray([
		"await requireAuthenticatedUser(userId);",
		"const details = await getVideoDetails(videoId);",
		"const recommendations = await getRecommendations(videoId);",
		"const comments = await getComments(videoId);",
		"return renderWatchPage({ details, recommendations, comments });",
	]))

func _test_file() -> String:
	return "\n".join(PackedStringArray([
		"import { renderWatchPage } from '../src/watch_page_orchestrator';",
		"",
		"describe('watch page orchestration', () => {",
		"  it('runs independent lookups concurrently', async () => {",
		"    await renderWatchPage('video-123');",
		"    expect(getVideoDetails).toHaveBeenCalled();",
		"    expect(getRecommendations).toHaveBeenCalled();",
		"    expect(getComments).toHaveBeenCalled();",
		"  });",
		"});",
	]))
