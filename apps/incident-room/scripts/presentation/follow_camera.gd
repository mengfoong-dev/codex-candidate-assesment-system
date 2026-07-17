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
@export var eye_height := 0.9  ## match the mini character: model 0.776 * 1.28 scale ≈ 0.99m tall, eyes just below the crown
@export var blend_speed := 3.5  ## how fast the view switch eases (higher = quicker)
## Radians of rotation per screen pixel of drag — equal for yaw and pitch (FPS best practice).
@export var look_sensitivity := 0.005
@export var tilt_limit := 1.4  ## clamp first-person pitch so it can't flip over

var _target: Node3D
var _visual: Node3D
var _yaw := 0.0
var _height_adj := 0.0
var _pitch := 0.0
var _blend := 0.0        ## 0 = third-person, 1 = first-person
var _blend_target := 0.0
var _third_pos := Vector3.ZERO
var _focus_active := false
var _focus_transform := Transform3D.IDENTITY
var _focus_weight := 0.0  ## eased 0->1 while focusing on a fixed view (e.g. the desk)
var _focus_yaw := 0.0     ## glance left/right while seated (drag), clamped so you stay at the desk
var _focus_pitch := 0.0   ## glance up/down while seated
const FOCUS_YAW_LIMIT := 0.6    ## ~34 deg
const FOCUS_PITCH_LIMIT := 0.35  ## ~20 deg

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

## Glide to and hold a fixed camera transform (the desk close-up). clear_focus() eases back.
func focus_on(xform: Transform3D) -> void:
    _focus_transform = xform
    _focus_active = true
    _focus_yaw = 0.0    # start centred on the monitor each time you sit
    _focus_pitch = 0.0

func clear_focus() -> void:
    _focus_active = false

## Drag-look from a screen-relative delta (resolution-independent, equal x/y sensitivity).
## Yaw always rotates; vertical tilts the first-person pitch or raises the third-person view.
func look_drag(screen_rel: Vector2) -> void:
    if _focus_active:
        # Seated at the desk: glance around within limits instead of orbiting/free-look.
        _focus_yaw = clampf(_focus_yaw - screen_rel.x * look_sensitivity, -FOCUS_YAW_LIMIT, FOCUS_YAW_LIMIT)
        _focus_pitch = clampf(_focus_pitch - screen_rel.y * look_sensitivity, -FOCUS_PITCH_LIMIT, FOCUS_PITCH_LIMIT)
        return
    _yaw = wrapf(_yaw - screen_rel.x * look_sensitivity, -PI, PI)
    if _blend_target > 0.5:
        _pitch = clampf(_pitch - screen_rel.y * look_sensitivity, -tilt_limit, tilt_limit)
    else:
        _height_adj = clampf(_height_adj + screen_rel.y * 0.012, -1.2, 3.5)

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
        # Hidden in first-person (blend) and once mostly into a focus view (seated desk),
        # so the body never clips the eye-level camera.
        _visual.visible = _blend < 0.5 and _focus_weight < 0.5

    # Smoothly trail the third-person anchor even while blended, so returning is stable.
    var desired := _target.global_position + _third_offset()
    _third_pos = _third_pos.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))

    var w := smoothstep(0.0, 1.0, _blend)
    var base := _third_transform().interpolate_with(_first_transform(), w)

    # Ease toward the focus view (desk close-up) when active, and back out when cleared.
    _focus_weight = move_toward(_focus_weight, 1.0 if _focus_active else 0.0, blend_speed * delta)
    if _focus_weight <= 0.001:
        global_transform = base
    else:
        # Glance rotation: pivot the seated view in place (position stays at the seat's eye).
        var focus_xf := _focus_transform
        focus_xf.basis = focus_xf.basis * Basis(Vector3.UP, _focus_yaw) * Basis(Vector3.RIGHT, _focus_pitch)
        global_transform = base.interpolate_with(focus_xf, smoothstep(0.0, 1.0, _focus_weight))
