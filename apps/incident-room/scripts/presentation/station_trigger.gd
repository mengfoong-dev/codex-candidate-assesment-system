class_name StationTrigger
extends Area3D

signal interaction_requested(station_id: String)

@export var station_id := ""
@export var station_title := "Station"
@export var accent_color := Color(0.2, 0.75, 0.95, 1.0)
## World-units above the trigger origin for the floating label. Stagger nearby stations
## (e.g. the desk vs. Sam) so their billboarded labels don't overlap on screen.
@export var label_height := 2.35

@onready var station_label: Label3D = $StationLabel

var _landmark: Node = null

func _ready() -> void:
    station_label.text = station_title
    station_label.modulate = accent_color
    station_label.position.y = label_height
    _landmark = get_node_or_null("Landmark")
    var lm := _landmark as Node3D
    if lm != null:
        lm.position.y = label_height + 0.4  # pip floats just above the name tag
        if lm.has_method("set_color"):
            lm.call("set_color", accent_color)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func request_interaction() -> void:
    interaction_requested.emit(station_id)

func _set_landmark_active(active: bool) -> void:
    if _landmark != null and _landmark.has_method("set_active"):
        _landmark.set_active(active)

func _on_body_entered(body: Node3D) -> void:
    if body.has_method("register_station"):
        body.register_station(self)
    _set_landmark_active(true)

func _on_body_exited(body: Node3D) -> void:
    if body.has_method("unregister_station"):
        body.unregister_station(self)
    _set_landmark_active(false)
