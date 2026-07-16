class_name StationVisual
extends Node3D

@export var idle_energy := 0.45
@export var active_energy := 1.3
@export var idle_ring_scale := 0.92
@export var active_ring_scale := 1.04

var _ring: Node3D
var _screens: Array[MeshInstance3D] = []
var _tween: Tween

func _ready() -> void:
    _ring = get_node_or_null("PromptRing")
    # Duplicate emissive screen materials so proximity animation stays local to this
    # station and never mutates the shared palette resources.
    for node: Node in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        var mat := mesh_instance.material_override
        if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
            mesh_instance.material_override = mat.duplicate()
            _screens.append(mesh_instance)
    _apply(false)

func set_active(active: bool) -> void:
    if _tween != null and _tween.is_running():
        _tween.kill()
    _tween = create_tween().set_parallel(true)
    var energy := active_energy if active else idle_energy
    for screen: MeshInstance3D in _screens:
        _tween.tween_property(screen.material_override, "emission_energy_multiplier", energy, 0.25)
    if _ring != null:
        var s := active_ring_scale if active else idle_ring_scale
        _tween.tween_property(_ring, "scale", Vector3(s, s, s), 0.25)

func _apply(active: bool) -> void:
    var energy := active_energy if active else idle_energy
    for screen: MeshInstance3D in _screens:
        (screen.material_override as StandardMaterial3D).emission_energy_multiplier = energy
    if _ring != null:
        var s := active_ring_scale if active else idle_ring_scale
        _ring.scale = Vector3(s, s, s)
