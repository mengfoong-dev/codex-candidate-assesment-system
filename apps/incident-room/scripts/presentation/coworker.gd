class_name Coworker
extends Node3D

## A background NPC seated at a desk. Instantiates its character model at runtime, scales it
## to room size, and holds a fixed pose (default "sit"). Lets one script drive every desk with
## a different Kenney character, so the office reads as a diverse, populated workspace.
@export var character: PackedScene
@export var character_scale := 1.28
@export var pose := "sit"
## Extra yaw applied to the seated body, in radians. Set to PI to flip 180° if the
## characters end up facing away from their desks.
@export var extra_yaw := 0.0

func _ready() -> void:
	if character == null:
		return
	var body: Node = character.instantiate()
	if body is Node3D:
		var b := body as Node3D
		b.scale = Vector3.ONE * character_scale
		b.rotate_y(extra_yaw)
	add_child(body)
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		if ap.has_animation(pose):
			ap.play(pose)
