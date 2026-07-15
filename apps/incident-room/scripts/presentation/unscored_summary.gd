class_name UnscoredSummary
extends Control

signal restart_requested

@onready var heading: Label = $Panel/Margin/Layout/Heading
@onready var status: Label = $Panel/Margin/Layout/Status
@onready var details: RichTextLabel = $Panel/Margin/Layout/Details
@onready var notices: RichTextLabel = $Panel/Margin/Layout/Notices
@onready var restart_button: Button = $Panel/Margin/Layout/Restart

func _ready() -> void:
    restart_button.pressed.connect(func(): restart_requested.emit())

func configure(summary: Dictionary) -> void:
    heading.text = str(summary.get("label", "Unscored prototype summary"))
    status.text = "%s • %s" % [
        "Session complete" if summary.get("completed", false) else "Session in progress",
        "Saved locally" if summary.get("saved_to_disk", false) else "In-memory only",
    ]
    if not str(summary.get("persistence_warning", "")).is_empty():
        status.text += "\n%s" % summary.persistence_warning
    details.text = _summary_text(summary)
    var summary_notices: Dictionary = summary.get("notices", {})
    notices.text = "%s\n\n%s\n\n%s" % [
        summary_notices.get("human_review", ""),
        summary_notices.get("limitations", ""),
        summary_notices.get("navigation", ""),
    ]
    restart_button.grab_focus.call_deferred()

func _summary_text(summary: Dictionary) -> String:
    var initial: Dictionary = summary.get("initial_hypothesis", {})
    var final_hypothesis: Dictionary = summary.get("final_hypothesis", {})
    var submission: Dictionary = summary.get("final_submission", {})
    var lines := PackedStringArray([
        "Initial hypothesis: %s" % initial.get("label", "Not recorded"),
        "Final hypothesis: %s" % final_hypothesis.get("label", "Not recorded"),
        "Evidence views: %d" % summary.get("evidence_timeline", []).size(),
        "Verification actions: %d" % summary.get("verification_actions", []).size(),
    ])
    if not submission.is_empty():
        lines.append("Root cause: %s" % submission.get("root_cause", {}).get("label", "Not recorded"))
        lines.append("Remediation: %s" % submission.get("remediation", {}).get("label", "Not recorded"))
        lines.append("Rollback: %s" % submission.get("rollback", {}).get("label", "Not recorded"))
        lines.append("Rationale: %s" % submission.get("rationale", ""))
    return "\n".join(lines)
