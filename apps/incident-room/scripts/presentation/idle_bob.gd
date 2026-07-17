class_name IdleBob
extends Node3D

## Adds subtle, always-on "breathing" life to a seated/posed NPC so it stops reading as a frozen
## mannequin: a tiny vertical bob plus a micro yaw-sway applied to THIS node (and so to its
## children). Each instance is desynced by a phase + frequency seeded from its own world position,
## so no two NPCs move in lockstep. The character's AnimationPlayer animates the skeleton *inside*
## this node, so it never fights the transform applied here on the parent.
##
## ponytail: procedural breathing on top of the static "sit" pose — these Kenney models ship no
## seated-work clip, and every other clip (idle/interact/emote) stands the character up. Upgrade
## path if this still reads flat: add a sine on the arm bones for a "typing" read (7-bone skeleton).

## Peak vertical travel, in metres. Tiny on purpose — this is breathing, not bouncing. Tune knob.
@export var bob_height := 0.012
## Overall rate multiplier (1.0 ≈ a calm resting breath). Tune knob.
@export var bob_speed := 1.0
## Peak yaw sway, in degrees. Tune knob.
@export var sway_degrees := 1.6

var _t := 0.0
var _phase := 0.0
var _freq := 1.0
var _base_y := 0.0
var _base_yaw := 0.0

func _ready() -> void:
	_base_y = position.y
	_base_yaw = rotation.y
	_phase = phase_for(global_position)
	# ±20% frequency spread so even two NPCs that happen to share a phase drift apart over time.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position) ^ 0x9e3779b9
	_freq = 0.85 + rng.randf() * 0.4

func _process(delta: float) -> void:
	_t += delta
	var w := _t * bob_speed * _freq
	position.y = _base_y + sin(w + _phase) * bob_height
	rotation.y = _base_yaw + sin(w * 0.6 + _phase * 1.7) * deg_to_rad(sway_degrees)

## Deterministic per-position phase in [0, TAU): same spot → same phase every run (stable renders),
## different spots → different phases (desynced NPCs). Static so tests can check desync scene-free.
static func phase_for(pos: Vector3) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	return rng.randf() * TAU
