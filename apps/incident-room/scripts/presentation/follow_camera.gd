class_name FollowCamera
extends Camera3D

## Third-person follow camera. Tracks the player at an offset that can be orbited
## (yaw) and raised/lowered (height) by dragging — see PlayerController input.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 3.2, 3.8)
@export var look_height := 1.0
@export var follow_speed := 6.0

var _target: Node3D
var _yaw := 0.0
var _height_adj := 0.0

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    if _target != null:
        global_position = _target.global_position + _current_offset()
        look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)

## Called by the player controller on a drag: rotate around the player and tilt.
func add_orbit(delta_yaw: float, delta_height: float) -> void:
    _yaw = wrapf(_yaw + delta_yaw, -PI, PI)
    _height_adj = clampf(_height_adj + delta_height, -1.2, 3.5)

func _current_offset() -> Vector3:
    var off := Basis(Vector3.UP, _yaw) * offset
    off.y = clampf(offset.y + _height_adj, 1.8, 7.0)
    return off

func _physics_process(delta: float) -> void:
    if _target == null:
        return
    var desired := _target.global_position + _current_offset()
    global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
    look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)
