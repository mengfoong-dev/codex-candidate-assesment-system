class_name PlayerVisual
extends Node3D

@export var idle_animation := "idle"
@export var walk_animation := "walk"

var _animation_player: AnimationPlayer
var _current := ""

func _ready() -> void:
    var candidates := find_children("*", "AnimationPlayer", true, false)
    if not candidates.is_empty():
        _animation_player = candidates[0] as AnimationPlayer
    set_moving(false)

func set_moving(moving: bool) -> void:
    var requested := walk_animation if moving else idle_animation
    if requested == _current or _animation_player == null:
        return
    if not _animation_player.has_animation(requested):
        push_warning("Player visual is missing animation: %s" % requested)
        return
    _animation_player.play(requested, 0.15)
    _current = requested
