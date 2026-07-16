class_name FollowCamera
extends Camera3D

## Two camera modes, toggled by the player:
##   THIRD  — follows the player from behind/above; drag orbits (yaw) and tilts (height).
##   FIRST  — first-person from the character's eyes; drag looks around (yaw/pitch); body hidden.
## Movement stays relative to where the camera looks in both modes.

enum Mode { THIRD, FIRST }

@export var target_path: NodePath
@export var offset := Vector3(0.0, 4.5, 6.0)
@export var look_height := 1.0
@export var follow_speed := 6.0
@export var eye_height := 1.55

var _target: Node3D
var _visual: Node3D
var _yaw := 0.0
var _height_adj := 0.0
var _pitch := 0.0
var _mode := Mode.THIRD

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    if _target != null:
        _visual = _target.get_node_or_null("Visual") as Node3D
        global_position = _target.global_position + _third_offset()
        look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)

func toggle_mode() -> void:
    _mode = Mode.FIRST if _mode == Mode.THIRD else Mode.THIRD
    if _visual != null:
        _visual.visible = _mode == Mode.THIRD  # hide the body in first-person
    if _mode == Mode.FIRST:
        _pitch = -0.05

func is_first_person() -> bool:
    return _mode == Mode.FIRST

## Drag input: yaw always; vertical tilts pitch (first-person) or height (third-person).
func add_orbit(delta_yaw: float, delta_vertical: float) -> void:
    _yaw = wrapf(_yaw + delta_yaw, -PI, PI)
    if _mode == Mode.FIRST:
        _pitch = clampf(_pitch - delta_vertical * 2.5, -1.1, 0.9)
    else:
        _height_adj = clampf(_height_adj + delta_vertical, -1.2, 3.5)

func _third_offset() -> Vector3:
    var off := Basis(Vector3.UP, _yaw) * offset
    off.y = clampf(offset.y + _height_adj, 1.8, 7.5)
    return off

func _physics_process(delta: float) -> void:
    if _target == null:
        return
    if _mode == Mode.FIRST:
        var head := _target.global_position + Vector3(0.0, eye_height, 0.0)
        global_transform = Transform3D(Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch), head)
    else:
        var desired := _target.global_position + _third_offset()
        global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
        look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)
