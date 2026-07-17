class_name TitleScreen
extends Control

## Single-beat entry: a sign-in that captures + validates the candidate email, then drops
## straight into the 3D office. The backstory is told in-game by Sam (not a title card), so
## the player reaches agency fast instead of reading the incident four times.
signal start_requested(email: String)

@onready var _email: LineEdit = $Entry/Col/Row/Email
@onready var _start: Button = $Entry/Col/Row/Start
@onready var _hint: Label = $Entry/Col/Hint
@onready var _notices: RichTextLabel = $Entry/Col/Notices
@onready var _story_body: RichTextLabel = $Story/Card/CardCol/SBody

var _stored_email := ""

func _ready() -> void:
	_start.pressed.connect(_on_continue)
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
		brief if not brief.is_empty() else "VibeTube's watch-page p95 latency jumped from 180 ms to 850 ms. CPU sits at 35%. The database and downstream services look healthy.",
		"",
		"[b]Your role[/b]",
		"You are the on-call engineer. Walk to your desk, open your PC, and investigate with the metrics, logs, traces, source code, and your AI copilot. Record a hypothesis, then verify it.",
		"",
		"[b]What \"done\" looks like[/b]",
		"Identify the real bottleneck, back it with evidence, and submit a safe fix — root cause, remediation, risks, and a validation plan. Rewriting the system is out of scope. AI use is allowed; showing how you verify it is the point.",
	])

func _on_continue() -> void:
	var email := _email.text.strip_edges()
	if not _is_valid_email(email):
		_hint.text = "Enter a valid email to start your session."
		_email.grab_focus()
		return
	_hint.text = ""
	_stored_email = email
	start_requested.emit(_stored_email)

func _is_valid_email(email: String) -> bool:
	# Minimal, permissive check — a local-part, one @, a dotted domain.
	var at := email.find("@")
	if at <= 0:
		return false
	var domain := email.substr(at + 1)
	return domain.length() >= 3 and domain.contains(".") and not domain.ends_with(".")
