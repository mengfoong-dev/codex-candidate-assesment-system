class_name PlayerVisual
extends Node3D

@export var idle_animation := "idle"
@export var walk_animation := "walk"
## A fixed looping pose to hold instead of idle/walk — e.g. "sit" for a seated NPC.
## When set, set_moving() is ignored so the pose stays put.
@export var start_animation := ""

var _animation_player: AnimationPlayer
var _current := ""

func _ready() -> void:
    var candidates := find_children("*", "AnimationPlayer", true, false)
    if not candidates.is_empty():
        _animation_player = candidates[0] as AnimationPlayer
        # glTF clips import non-looping, so walk/idle play once then freeze while the body
        # keeps moving ("2 steps then glide"). Force them to loop.
        for clip in [idle_animation, walk_animation]:
            if _animation_player.has_animation(clip):
                _animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
    if not start_animation.is_empty() and _animation_player != null and _animation_player.has_animation(start_animation):
        _animation_player.play(start_animation)
        _current = start_animation
    else:
        set_moving(false)

var _seated := false

func set_moving(moving: bool) -> void:
    if not start_animation.is_empty() or _seated:
        return  # seated/posed: never switch to walk/idle
    var requested := walk_animation if moving else idle_animation
    if requested == _current or _animation_player == null:
        return
    if not _animation_player.has_animation(requested):
        push_warning("Player visual is missing animation: %s" % requested)
        return
    _animation_player.play(requested, 0.15)
    _current = requested

## Toggle a seated pose on/off at runtime (used when the player sits at the desk).
func set_seated(seated: bool) -> void:
    _seated = seated
    if _animation_player == null:
        return
    var clip := "sit" if seated else idle_animation
    if _animation_player.has_animation(clip):
        _animation_player.play(clip, 0.2)
        _current = clip
