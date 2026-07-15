class_name BriefingPanel
extends Control

signal hypothesis_submitted(hypothesis_id: String, confidence: int)

@onready var role_label: Label = $Panel/Margin/Layout/Role
@onready var brief_label: RichTextLabel = $Panel/Margin/Layout/Brief
@onready var hypothesis_option: OptionButton = $Panel/Margin/Layout/Hypothesis
@onready var confidence_slider: HSlider = $Panel/Margin/Layout/Confidence
@onready var confidence_value: Label = $Panel/Margin/Layout/ConfidenceValue
@onready var confirm_button: Button = $Panel/Margin/Layout/Confirm

var _hypothesis_selected := false
var _confidence_selected := false
var _configured := false

func _ready() -> void:
    hypothesis_option.item_selected.connect(_on_hypothesis_selected)
    confidence_slider.value_changed.connect(_on_confidence_changed)
    confirm_button.pressed.connect(_submit)

func configure(scenario: Dictionary) -> void:
    _configured = false
    role_label.text = "%s — %s" % [scenario.get("title", "Incident briefing"), scenario.get("role", "Candidate")]
    brief_label.text = str(scenario.get("brief", ""))
    hypothesis_option.clear()
    for hypothesis: Dictionary in scenario.get("hypotheses", []):
        hypothesis_option.add_item(str(hypothesis.get("label", hypothesis.get("hypothesis_id", ""))))
        hypothesis_option.set_item_metadata(hypothesis_option.item_count - 1, hypothesis.get("hypothesis_id", ""))
    hypothesis_option.select(-1)
    confidence_slider.value = 50
    confidence_value.text = "Confidence: 50%"
    _hypothesis_selected = false
    _confidence_selected = false
    confirm_button.disabled = true
    _configured = true
    hypothesis_option.grab_focus.call_deferred()

func _on_hypothesis_selected(_index: int) -> void:
    _hypothesis_selected = hypothesis_option.selected >= 0
    _update_confirm_state()

func _on_confidence_changed(value: float) -> void:
    confidence_value.text = "Confidence: %d%%" % int(value)
    if _configured:
        _confidence_selected = true
    _update_confirm_state()

func _update_confirm_state() -> void:
    confirm_button.disabled = not (_hypothesis_selected and _confidence_selected)

func _submit() -> void:
    if confirm_button.disabled:
        return
    hypothesis_submitted.emit(
        str(hypothesis_option.get_item_metadata(hypothesis_option.selected)),
        int(confidence_slider.value)
    )

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        hide()

