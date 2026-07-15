class_name ReleasePanel
extends Control

signal verification_requested(test_id: String, remediation_id: String)
signal final_submission_requested(submission: Dictionary)

@onready var root_cause: OptionButton = $Panel/Margin/Layout/RootCause
@onready var evidence: ItemList = $Panel/Margin/Layout/Evidence
@onready var remediation: OptionButton = $Panel/Margin/Layout/Remediation
@onready var risks: ItemList = $Panel/Margin/Layout/Risks
@onready var assumptions: ItemList = $Panel/Margin/Layout/Assumptions
@onready var validation: ItemList = $Panel/Margin/Layout/Validation
@onready var rollback: OptionButton = $Panel/Margin/Layout/Rollback
@onready var confidence: HSlider = $Panel/Margin/Layout/Confidence
@onready var confidence_value: Label = $Panel/Margin/Layout/ConfidenceValue
@onready var rationale: TextEdit = $Panel/Margin/Layout/Rationale
@onready var verify_button: Button = $Panel/Margin/Layout/Actions/Verify
@onready var submit_button: Button = $Panel/Margin/Layout/Actions/Submit

func _ready() -> void:
    root_cause.item_selected.connect(func(_index): _update_actions())
    remediation.item_selected.connect(func(_index): _update_actions())
    rollback.item_selected.connect(func(_index): _update_actions())
    validation.multi_selected.connect(func(_index, _selected): _update_actions())
    confidence.value_changed.connect(func(value): confidence_value.text = "Final confidence: %d%%" % int(value))
    verify_button.pressed.connect(_request_verification)
    submit_button.pressed.connect(_submit)

func configure(scenario: Dictionary, snapshot: Dictionary) -> void:
    var options: Dictionary = scenario.get("submission_options", {})
    _populate_options(root_cause, options.get("root_causes", []))
    _populate_options(remediation, options.get("remediations", []))
    _populate_options(rollback, options.get("rollbacks", []))
    _populate_items(risks, options.get("risks", []), "option_id")
    _populate_items(assumptions, options.get("assumptions", []), "option_id")
    _populate_items(validation, scenario.get("tests", []), "test_id", "title")
    evidence.clear()
    for artifact_id: Variant in snapshot.get("viewed_artifact_ids", []):
        var artifact := _find_by_id(scenario.get("artifacts", []), "artifact_id", str(artifact_id))
        evidence.add_item(str(artifact.get("title", artifact_id)))
        evidence.set_item_metadata(evidence.item_count - 1, artifact_id)
    confidence.value = 50
    confidence_value.text = "Final confidence: 50%"
    rationale.text = ""
    _update_actions()
    root_cause.grab_focus.call_deferred()

func _populate_options(control: OptionButton, items: Variant) -> void:
    control.clear()
    for item: Dictionary in items if typeof(items) == TYPE_ARRAY else []:
        control.add_item(str(item.get("label", item.get("option_id", ""))))
        control.set_item_metadata(control.item_count - 1, item.get("option_id", ""))
    control.select(-1)

func _populate_items(control: ItemList, items: Variant, id_field: String, label_field: String = "label") -> void:
    control.clear()
    for item: Dictionary in items if typeof(items) == TYPE_ARRAY else []:
        control.add_item(str(item.get(label_field, item.get(id_field, ""))))
        control.set_item_metadata(control.item_count - 1, item.get(id_field, ""))

func _update_actions() -> void:
    verify_button.disabled = remediation.selected < 0 or validation.get_selected_items().is_empty()
    submit_button.disabled = (
        root_cause.selected < 0
        or remediation.selected < 0
        or validation.get_selected_items().is_empty()
        or rollback.selected < 0
    )

func _request_verification() -> void:
    if verify_button.disabled:
        return
    var test_index: int = validation.get_selected_items()[0]
    verification_requested.emit(
        str(validation.get_item_metadata(test_index)),
        str(remediation.get_item_metadata(remediation.selected))
    )

func _submit() -> void:
    if submit_button.disabled:
        return
    final_submission_requested.emit({
        "root_cause_id": root_cause.get_item_metadata(root_cause.selected),
        "evidence_ids": _selected_metadata(evidence),
        "remediation_id": remediation.get_item_metadata(remediation.selected),
        "risk_ids": _selected_metadata(risks),
        "assumption_ids": _selected_metadata(assumptions),
        "validation_test_ids": _selected_metadata(validation),
        "rollback_id": rollback.get_item_metadata(rollback.selected),
        "final_confidence": int(confidence.value),
        "rationale": rationale.text,
    })

func _selected_metadata(control: ItemList) -> Array:
    var ids: Array = []
    for index: int in control.get_selected_items():
        ids.append(control.get_item_metadata(index))
    return ids

func _find_by_id(items: Variant, field: String, requested_id: String) -> Dictionary:
    for item: Variant in items if typeof(items) == TYPE_ARRAY else []:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(field, "")) == requested_id:
            return item
    return {}

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        hide()

