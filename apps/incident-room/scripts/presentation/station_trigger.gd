class_name StationTrigger
extends Area3D

signal interaction_requested(station_id: String)

@export var station_id := ""
@export var station_title := "Station"
@export var accent_color := Color(0.2, 0.75, 0.95, 1.0)

@onready var station_mesh: MeshInstance3D = $StationMesh
@onready var station_label: Label3D = $StationLabel

func _ready() -> void:
    station_label.text = station_title
    var material := StandardMaterial3D.new()
    material.albedo_color = accent_color
    material.metallic = 0.1
    material.roughness = 0.6
    station_mesh.material_override = material
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func request_interaction() -> void:
    interaction_requested.emit(station_id)

func _on_body_entered(body: Node3D) -> void:
    if body.has_method("register_station"):
        body.register_station(self)

func _on_body_exited(body: Node3D) -> void:
    if body.has_method("unregister_station"):
        body.unregister_station(self)
