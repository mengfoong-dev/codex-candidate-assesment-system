class_name TitleScreen
extends Control

## Two-beat entry: (1) cinematic sign-in that captures the candidate email, then
## (2) a mission-brief story card, before dropping into the 3D office.
signal start_requested(email: String)

@onready var _entry: Control = $Entry
@onready var _story: Control = $Story
@onready var _email: LineEdit = $Entry/Col/Row/Email
@onready var _start: Button = $Entry/Col/Row/Start
@onready var _hint: Label = $Entry/Col/Hint
@onready var _notices: RichTextLabel = $Entry/Col/Notices
@onready var _story_body: RichTextLabel = $Story/Card/CardCol/SBody
@onready var _enter: Button = $Story/Card/CardCol/SEnter

var _stored_email := ""

func _ready() -> void:
	_start.pressed.connect(_on_continue)
	_enter.pressed.connect(_on_enter)
	_start.grab_focus.call_deferred()

func configure(scenario: Dictionary) -> void:
	var notices: Dictionary = scenario.get("notices", {})
	_notices.text = "%s  %s  %s" % [
		notices.get("human_review", ""),
		notices.get("limitations", ""),
		notices.get("navigation", ""),
	]
	var brief: String = scenario.get("brief", "")
	_story_body.text = "\n".join([
		"[b]What happened[/b]",
		brief if not brief.is_empty() else "The homepage p95 latency jumped from 180 ms to 850 ms. CPU sits at 35%. The database and downstream services look healthy.",
		"",
		"[b]Your role[/b]",
		"You are the on-call engineer. Walk to your desk, open your PC, and investigate with the metrics, logs, traces, source code, and your AI copilot. Record a hypothesis, then verify it.",
		"",
		"[b]What \"done\" looks like[/b]",
		"Identify the real bottleneck, back it with evidence, and submit a safe fix — root cause, remediation, risks, and a validation plan. Rewriting the system is out of scope. AI use is allowed; showing how you verify it is the point.",
	])

func _on_continue() -> void:
	_hint.text = ""
	_stored_email = ""
	_entry.visible = false
	_story.visible = true
	_enter.grab_focus.call_deferred()

func _on_enter() -> void:
	start_requested.emit(_stored_email)

func _is_valid_email(email: String) -> bool:
	# Minimal, permissive check — a local-part, one @, a dotted domain.
	var at := email.find("@")
	if at <= 0:
		return false
	var domain := email.substr(at + 1)
	return domain.length() >= 3 and domain.contains(".") and not domain.ends_with(".")
