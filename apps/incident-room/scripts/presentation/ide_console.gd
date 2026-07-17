class_name IDEConsole
extends Control

## In-game "Codex" IDE: a dark, VS Code-style editor + terminal over the incident source code.
## The candidate reads/edits the real scenario source and asks "Codex" (the senior-proxy assistant)
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

## Live in-workspace copilot endpoint (the senior-proxy assistant route).
@export var assistant_proxy_url := "https://senior-proxy-production-82cf.up.railway.app/api/assistant/chat"
@export var test_runner_url := "http://localhost:18080/api/assistant/test"
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
@onready var _title: Label = $Body/Margin/Rows/TitleBar/Title
@onready var _close: Button = $Body/Margin/Rows/TitleBar/Close
@onready var _file_rail: ItemList = $Body/Margin/Rows/Split/FileRail
@onready var _editor: CodeEdit = $Body/Margin/Rows/Split/Right/Editor
@onready var _term: PanelContainer = $Body/Margin/Rows/Split/Right/Term
@onready var _scroll: RichTextLabel = $Body/Margin/Rows/Split/Right/Term/TV/Scroll
@onready var _input: LineEdit = $Body/Margin/Rows/Split/Right/Term/TV/PromptRow/Input

var _http: HTTPRequest
var _files := {}          # path -> source text
var _brief := ""
var _history: Array = []  # [{role, content}] sent to the assistant
var _lines: Array = []    # terminal scrollback (bbcode lines)
var _busy := false
var _paused_by_us := false
var _request_kind := "chat"

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_reply)
	_apply_theme()
	_close.pressed.connect(hide_console)
	_input.text_submitted.connect(_on_submit)
	_file_rail.item_selected.connect(func(i: int) -> void: _show_file(_file_rail.get_item_text(i)))
	_seed_from_scenario()
	_hint.visible = false  # PC-only now: opened from the workspace, not a floating backtick hint
	_log("[color=#858585]Codex online. Read the source on the left, then ask for a change below.[/color]")
	if not _brief.is_empty():
		_log("[color=#858585]incident: %s[/color]" % _escape(_brief))

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
	var editor_box := _flat(BG, 10, 8)
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
	_term.add_theme_stylebox_override("panel", _flat(PANEL, 10, 8))
	_scroll.add_theme_color_override("default_color", Color("cccccc"))
	_scroll.add_theme_font_size_override("normal_font_size", 14)
	_title.add_theme_color_override("font_color", MUTED)
	_hint.add_theme_color_override("font_color", Color("cccccc"))
	_hint.add_theme_stylebox_override("normal", _flat(Color(0.09, 0.09, 0.09, 0.85), 8, 4))
	if mono != null:
		_editor.add_theme_font_override("font", mono)
		_scroll.add_theme_font_override("normal_font", mono)
		_scroll.add_theme_font_override("bold_font", mono)
		for c in [_title, _input, _file_rail, _hint]:
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
	_files[EDITOR_TAB] = src
	_file_rail.clear()
	_file_rail.add_item(EDITOR_TAB)
	_file_rail.select(0)
	_show_file(EDITOR_TAB)

func _lookup(items: Variant, key: String, value: String) -> Dictionary:
	if items is Array:
		for it in items:
			if it is Dictionary and str(it.get(key, "")) == value:
				return it
	return {}

func _show_file(path: String) -> void:
	_editor.text = str(_files.get(path, ""))
	_title.text = "CODEX  —  %s" % path

# --- prompt -> assistant -> apply ---------------------------------------

func _on_submit(text: String) -> void:
	var prompt := text.strip_edges()
	if prompt.is_empty() or _busy:
		return
	_input.clear()
	_log("[color=#4ec9b0]▸ you[/color]  %s" % _escape(prompt))
	if prompt.to_lower() in ["test", "npm test"]:
		run_tests()
		return
	_history.append({"role": "user", "content": prompt})
	_busy = true
	_request_kind = "chat"
	_input.editable = false
	_log("[color=#858585]codex is thinking…[/color]")
	var payload := {"messages": _history, "task": _task_context()}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(assistant_proxy_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		apply_assistant_reply(_offline_reply())

func run_tests() -> void:
	if _busy:
		return
	_busy = true
	_request_kind = "test"
	_input.editable = false
	_log("[color=#858585]running isolated scenario tests…[/color]")
	var payload := {"code": _editor.text}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(test_runner_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		apply_test_result({"status": "unavailable", "error": "could not reach the test runner"})

func _task_context() -> String:
	return "\n".join(PackedStringArray([
		_brief,
		"The candidate is editing %s. Current contents:" % EDITOR_TAB,
		_editor.text,
		"When you change the code, reply with a one-line explanation then the FULL updated file in one ```ts fenced block.",
	]))

func _on_reply(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _busy:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if _request_kind == "test":
		if code == 200 and parsed is Dictionary:
			apply_test_result(parsed)
		else:
			apply_test_result({"status": "unavailable", "error": "test runner returned HTTP %d" % code})
		return
	var reply := str(parsed.get("reply", "")) if parsed is Dictionary and code == 200 else ""
	apply_assistant_reply(reply if not reply.is_empty() else _offline_reply())

func apply_test_result(result: Dictionary) -> void:
	_remove_thinking()
	var status := str(result.get("status", "unavailable"))
	if status == "unavailable":
		_log("[color=#f48771]tests unavailable: %s[/color]" % _escape(str(result.get("error", "unknown error"))))
	else:
		for test: Variant in result.get("tests", []):
			var row: Dictionary = test
			var passed := str(row.get("status", "")) == "passed"
			var marker := "✓" if passed else "✗"
			var color := "#6a9955" if passed else "#f48771"
			_log("[color=%s]%s %s[/color]" % [color, marker, _escape(str(row.get("name", "test")))])
			if not passed and not str(row.get("message", "")).is_empty():
				_log("[color=#f48771]  %s[/color]" % _escape(str(row.get("message", ""))))
		var summary := "%d passed, %d failed · %d ms · exit %d" % [
			int(result.get("passed", 0)),
			int(result.get("failed", 0)),
			int(result.get("duration_ms", 0)),
			int(result.get("exit_code", 1)),
		]
		_log("[color=%s]%s[/color]" % ["#6a9955" if status == "passed" else "#f48771", summary])
	_busy = false
	_request_kind = "chat"
	_input.editable = true

## The one testable seam: given an assistant reply, log the prose and apply any fenced code block
## into the editor. Called by both the live response handler and the offline fallback.
func apply_assistant_reply(reply: String) -> void:
	_history.append({"role": "assistant", "content": reply})
	_remove_thinking()
	var prose := _strip_code(reply)
	_log("[color=#dcdcaa]codex[/color]  %s" % _escape(prose if not prose.strip_edges().is_empty() else reply))
	var code := _extract_code(reply)
	if not code.is_empty():
		_files[EDITOR_TAB] = code
		_editor.text = code
		_log("[color=#6a9955]✓ applied Codex's edit to %s[/color]" % EDITOR_TAB)
	_busy = false
	_input.editable = true

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

# --- terminal scrollback -------------------------------------------------

func _log(bbcode_line: String) -> void:
	_lines.append(bbcode_line)
	if is_instance_valid(_scroll):
		_scroll.text = "\n".join(_lines)

func _remove_thinking() -> void:
	if _lines.size() > 0 and str(_lines[_lines.size() - 1]).contains("thinking…"):
		_lines.remove_at(_lines.size() - 1)
		if is_instance_valid(_scroll):
			_scroll.text = "\n".join(_lines)

func _escape(s: String) -> String:
	return s.replace("[", "[lb]")

# --- offline fallbacks (no backend / proxy) ------------------------------

func _offline_reply() -> String:
	return "Codex is offline. From the trace the three data fetches run sequentially — they're independent, so parallelize them with Promise.all. Applying the reference fix.\n```ts\n%s\n```" % _reference_fix()

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
