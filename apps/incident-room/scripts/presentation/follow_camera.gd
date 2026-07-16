class_name FollowCamera
extends Camera3D

## Two camera modes with a smooth blend between them:
##   THIRD — follows the player from behind/above; drag orbits (yaw) and tilts (height).
##   FIRST — first-person from the character's eyes; drag looks around (yaw/pitch); body hidden.
## Toggling eases a blend factor 0<->1 so the switch glides instead of snapping.
## Movement stays relative to where the camera looks in both modes.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 4.5, 6.0)
@export var look_height := 1.0
@export var follow_speed := 8.0
@export var eye_height := 1.55
@export var blend_speed := 3.5  ## how fast the view switch eases (higher = quicker)

var _target: Node3D
var _visual: Node3D
var _yaw := 0.0
var _height_adj := 0.0
var _pitch := 0.0
var _blend := 0.0        ## 0 = third-person, 1 = first-person
var _blend_target := 0.0
var _third_pos := Vector3.ZERO

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    if _target != null:
        _visual = _target.get_node_or_null("Visual") as Node3D
        _third_pos = _target.global_position + _third_offset()
        global_transform = _third_transform()

func toggle_mode() -> void:
    _blend_target = 1.0 if _blend_target < 0.5 else 0.0
    if _blend_target > 0.5:
        _pitch = -0.05

func is_first_person() -> bool:
    return _blend_target > 0.5

## Drag input: yaw always; vertical tilts pitch (first-person) or height (third-person).
func add_orbit(delta_yaw: float, delta_vertical: float) -> void:
    _yaw = wrapf(_yaw + delta_yaw, -PI, PI)
    if _blend_target > 0.5:
        _pitch = clampf(_pitch - delta_vertical * 2.5, -1.1, 0.9)
    else:
        _height_adj = clampf(_height_adj + delta_vertical, -1.2, 3.5)

func _third_offset() -> Vector3:
    var off := Basis(Vector3.UP, _yaw) * offset
    off.y = clampf(offset.y + _height_adj, 1.8, 7.5)
    return off

func _third_transform() -> Transform3D:
    var t := Transform3D.IDENTITY
    t.origin = _third_pos
    return t.looking_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)

func _first_transform() -> Transform3D:
    var head := _target.global_position + Vector3(0.0, eye_height, 0.0)
    return Transform3D(Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch), head)

func _physics_process(delta: float) -> void:
    if _target == null:
        return
    # Ease the blend toward its target, then hide the body once mostly first-person.
    _blend = move_toward(_blend, _blend_target, blend_speed * delta)
    if _visual != null:
        _visual.visible = _blend < 0.5

    # Smoothly trail the third-person anchor even while blended, so returning is stable.
    var desired := _target.global_position + _third_offset()
    _third_pos = _third_pos.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))

    var w := smoothstep(0.0, 1.0, _blend)
    global_transform = _third_transform().interpolate_with(_first_transform(), w)
