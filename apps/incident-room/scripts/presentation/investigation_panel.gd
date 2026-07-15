class_name InvestigationPanel
extends Control

signal artifact_viewed(artifact_id: String)
signal ai_disposition_selected(option_id: String)

@onready var heading: Label = $Panel/Margin/Layout/Heading
@onready var artifacts: VBoxContainer = $Panel/Margin/Layout/Artifacts
@onready var ai_response: RichTextLabel = $Panel/Margin/Layout/AIResponse
@onready var ai_disposition: OptionButton = $Panel/Margin/Layout/AIDisposition
@onready var ai_confirm: Button = $Panel/Margin/Layout/AIConfirm

func _ready() -> void:
    ai_disposition.item_selected.connect(func(_index): ai_confirm.disabled = false)
    ai_confirm.pressed.connect(_submit_ai_disposition)

func configure(station_id: String, scenario: Dictionary, snapshot: Dictionary) -> void:
    _clear_children(artifacts)
    var station := _find_by_id(scenario.get("stations", []), "station_id", station_id)
    heading.text = str(station.get("title", station_id))
    var viewed: Array = snapshot.get("viewed_artifact_ids", [])
    for artifact: Dictionary in scenario.get("artifacts", []):
        if str(artifact.get("station_id", "")) != station_id:
            continue
        var button := Button.new()
        var artifact_id := str(artifact.get("artifact_id", ""))
        button.text = "%s%s" % [artifact.get("title", artifact_id), "  • viewed" if viewed.has(artifact_id) else ""]
        button.tooltip_text = "\n".join(PackedStringArray(artifact.get("content", [])))
        button.focus_mode = Control.FOCUS_ALL
        button.pressed.connect(func(): artifact_viewed.emit(artifact_id))
        artifacts.add_child(button)

    var interaction: Dictionary = scenario.get("ai_interaction", {})
    var response: Dictionary = interaction.get("response", {})
    ai_response.text = "Scripted offline assistant\n%s" % response.get("text", "")
    ai_disposition.clear()
    for option: Dictionary in interaction.get("dispositions", []):
        ai_disposition.add_item(_humanize(str(option.get("disposition", option.get("option_id", "")))))
        ai_disposition.set_item_metadata(ai_disposition.item_count - 1, option.get("option_id", ""))
    ai_disposition.select(-1)
    ai_confirm.disabled = true
    var first_control: Control = artifacts.get_child(0) if artifacts.get_child_count() > 0 else ai_disposition
    first_control.grab_focus.call_deferred()

func _submit_ai_disposition() -> void:
    if ai_disposition.selected >= 0:
        ai_disposition_selected.emit(str(ai_disposition.get_item_metadata(ai_disposition.selected)))

func _clear_children(node: Node) -> void:
    for child: Node in node.get_children():
        node.remove_child(child)
        child.free()

func _find_by_id(items: Variant, field: String, requested_id: String) -> Dictionary:
    for item: Variant in items if typeof(items) == TYPE_ARRAY else []:
        if typeof(item) == TYPE_DICTIONARY and str(item.get(field, "")) == requested_id:
            return item
    return {}

func _humanize(value: String) -> String:
    return value.replace("_", " ").capitalize()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        hide()

