class_name DeskActivity
extends Node

## Gives a seated NPC a subtle "working at a desk" motion on top of the static sit pose: the arms
## do a small alternating typing oscillation and the head bobs slightly. Each NPC is desynced by a
## per-position phase so the floor doesn't type in unison.
##
## Why it captures the pose and stops the AnimationPlayer instead of using a SkeletonModifier: the
## AnimationMixer writes bone poses *after* the modifier pass here (Godot runtime-added modifiers),
## so modifier writes get overwritten. Capturing the sit pose once and then owning the skeleton
## sidesteps the ordering entirely — nothing else writes these bones.
##
## ponytail: bone axis (RIGHT) + amplitudes are tune-by-eye knobs — the Kenney rig's local axes
## aren't known up front. Adjust the consts if a future model rigs its arms differently.

const ARM_DEGREES := 9.0
const HEAD_DEGREES := 3.5
const TEMPO := 6.0

var _skel: Skeleton3D
var _base: Array[Quaternion] = []
var _arm_l := -1
var _arm_r := -1
var _head := -1
var _phase := 0.0

func _process(_delta: float) -> void:
	if _skel == null:
		return
	# Hold the captured sit pose on every bone (nothing else drives the skeleton now)...
	for i in _base.size():
		_skel.set_bone_pose_rotation(i, _base[i])
	# ...then layer the working motion on the arms and head.
	var t := float(Time.get_ticks_msec()) / 1000.0 * TEMPO + _phase
	if _arm_l >= 0:
		_skel.set_bone_pose_rotation(_arm_l, _base[_arm_l] * offset(t, ARM_DEGREES, false))
	if _arm_r >= 0:
		# alternate=true → opposite phase, so the hands alternate like typing rather than both
		# arms flapping in unison.
		_skel.set_bone_pose_rotation(_arm_r, _base[_arm_r] * offset(t, ARM_DEGREES, true))
	if _head >= 0:
		_skel.set_bone_pose_rotation(_head, _base[_head] * offset(t * 0.3, HEAD_DEGREES, false))

## Pitch offset for one bone at time t: a sine swing of ±degrees about the local X axis. alternate
## flips the phase by PI so paired bones (the two arms) move in opposition. Pure + static so the
## motion math is testable without a skeleton.
static func offset(t: float, degrees: float, alternate: bool) -> Quaternion:
	var phase := PI if alternate else 0.0
	return Quaternion(Vector3.RIGHT, deg_to_rad(degrees) * sin(t + phase))

## Find the character's Skeleton3D, capture its (already-applied) sit pose, stop its AnimationPlayer,
## and take over. Used by both coworkers (coworker.gd) and Sam (player_visual.gd) — call AFTER the
## sit pose has been forced onto the skeleton (ap.play(pose); ap.seek(0, true)).
static func attach_to(body: Node) -> void:
	var skels := body.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	for ap in body.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
	var da := DeskActivity.new()
	skel.add_child(da)
	da._capture(skel)

func _capture(skel: Skeleton3D) -> void:
	_skel = skel
	_arm_l = skel.find_bone("arm-left")
	_arm_r = skel.find_bone("arm-right")
	_head = skel.find_bone("head")
	_base.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		_base[i] = skel.get_bone_pose_rotation(i)
	_phase = IdleBob.phase_for(skel.global_position)
