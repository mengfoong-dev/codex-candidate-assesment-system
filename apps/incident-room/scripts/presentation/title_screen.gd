class_name TitleScreen
extends Control

signal start_requested

@onready var notices_label: RichTextLabel = $Margin/Layout/Notices
@onready var start_button: Button = $Margin/Layout/Start

func _ready() -> void:
    start_button.pressed.connect(func(): start_requested.emit())
    start_button.grab_focus.call_deferred()

func configure(notices: Dictionary) -> void:
    notices_label.text = "%s\n\n%s\n\n%s" % [
        notices.get("human_review", ""),
        notices.get("limitations", ""),
        notices.get("navigation", ""),
    ]

