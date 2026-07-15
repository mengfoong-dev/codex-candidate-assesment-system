class_name HypothesisPanel
extends Control

signal revision_submitted(hypothesis_id: String, confidence: int, fact_ids: Array)

@onready var current: Label = $Panel/Margin/Layout/Current
@onready var hypothesis_option: OptionButton = $Panel/Margin/Layout/Hypothesis
@onready var confidence_slider: HSlider = $Panel/Margin/Layout/Confidence
@onready var confidence_value: Label = $Panel/Margin/Layout/ConfidenceValue
@onready var facts: ItemList = $Panel/Margin/Layout/Facts
@onready var submit_button: Button = $Panel/Margin/Layout/Submit

func _ready() -> void:
    hypothesis_option.item_selected.connect(func(_index): submit_button.disabled = false)
    confidence_slider.value_changed.connect(func(value): confidence_value.text = "Confidence: %d%%" % int(value))
    submit_button.pressed.connect(_submit)

func configure(scenario: Dictionary, snapshot: Dictionary) -> void:
    var current_hypothesis: Dictionary = snapshot.get("current_hypothesis", {})
    current.text = "Current hypothesis: %s" % _hypothesis_label(scenario, str(current_hypothesis.get("hypothesis_id", "Not recorded")))
    hypothesis_option.clear()
    for hypothesis: Dictionary in scenario.get("hypotheses", []):
        hypothesis_option.add_item(str(hypothesis.get("label", hypothesis.get("hypothesis_id", ""))))
        hypothesis_option.set_item_metadata(hypothesis_option.item_count - 1, hypothesis.get("hypothesis_id", ""))
    hypothesis_option.select(-1)
    confidence_slider.value = int(current_hypothesis.get("confidence", 50))
    confidence_value.text = "Confidence: %d%%" % int(confidence_slider.value)
    facts.clear()
    var viewed: Array = snapshot.get("viewed_artifact_ids", [])
    for artifact: Dictionary in scenario.get("artifacts", []):
        if not viewed.has(str(artifact.get("artifact_id", ""))):
            continue
        for fact: Dictionary in artifact.get("facts", []):
            facts.add_item(str(fact.get("label", fact.get("fact_id", ""))))
            facts.set_item_metadata(facts.item_count - 1, fact.get("fact_id", ""))
    submit_button.disabled = true
    hypothesis_option.grab_focus.call_deferred()

func _submit() -> void:
    if submit_button.disabled:
        return
    var fact_ids: Array = []
    for index: int in facts.get_selected_items():
        fact_ids.append(facts.get_item_metadata(index))
    revision_submitted.emit(
        str(hypothesis_option.get_item_metadata(hypothesis_option.selected)),
        int(confidence_slider.value),
        fact_ids
    )

func _hypothesis_label(scenario: Dictionary, hypothesis_id: String) -> String:
    for hypothesis: Dictionary in scenario.get("hypotheses", []):
        if str(hypothesis.get("hypothesis_id", "")) == hypothesis_id:
            return str(hypothesis.get("label", hypothesis_id))
    return hypothesis_id

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        hide()

