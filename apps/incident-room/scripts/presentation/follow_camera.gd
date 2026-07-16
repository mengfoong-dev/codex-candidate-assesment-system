class_name FollowCamera
extends Camera3D

## Third-person follow camera: tracks the player's position at a fixed behind-and-above
## offset (constant world angle, so movement stays intuitive and the view never spins).

@export var target_path: NodePath
@export var offset := Vector3(0.0, 5.5, 6.5)
@export var look_height := 1.2
@export var follow_speed := 6.0

var _target: Node3D

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    if _target != null:
        global_position = _target.global_position + offset
        look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)

func _physics_process(delta: float) -> void:
    if _target == null:
        return
    var desired := _target.global_position + offset
    global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
    look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)
