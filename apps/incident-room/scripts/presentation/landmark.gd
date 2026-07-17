class_name Landmark
extends Node3D
## A small glowing pip floating above a station. Idle: dim + slow bob — a waymarker you can
## spot from across the room. In interaction range (set_active(true)): bright + quick pulse +
## bigger, so "you can interact now" reads at a glance, at any camera height.
##
## Uses an unshaded, alpha-modulated material rather than bloom: the project runs the GL
## Compatibility renderer, which has no environment glow, so brightness is faked by fading the
## pip's opacity up/down. That still reads as a glow without needing Forward+.

@export var color := Color(0.2, 0.75, 0.95)

var _active := false
var _t := 0.0
var _mat: StandardMaterial3D
@onready var _orb: MeshInstance3D = $Orb

func _ready() -> void:
    var m := _orb.material_override as StandardMaterial3D
    if m != null:
        _mat = m.duplicate()  # per-instance, so each station keeps its own colour
        _orb.material_override = _mat
    _apply_base()

func set_color(c: Color) -> void:
    color = c
    _apply_base()

func set_active(active: bool) -> void:
    _active = active

func _apply_base() -> void:
    if _mat != null:
        _mat.albedo_color = Color(color.r, color.g, color.b, _mat.albedo_color.a)

func _process(delta: float) -> void:
    if _mat == null:
        return
    _t += delta
    var pulse := 0.5 + 0.5 * sin(_t * (7.0 if _active else 2.2))
    # Opacity stands in for brightness: idle sits faint, active flares and pulses.
    var a := (0.8 + 0.2 * pulse) if _active else (0.35 + 0.12 * pulse)
    _mat.albedo_color = Color(color.r, color.g, color.b, a)
    _orb.position.y = 0.06 * sin(_t * (3.5 if _active else 1.6))
    _orb.scale = Vector3.ONE * ((1.3 + 0.25 * pulse) if _active else 0.85)
