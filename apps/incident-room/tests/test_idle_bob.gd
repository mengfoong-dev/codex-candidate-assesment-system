extends RefCounted

## The 6 coworker seats + Sam, at their real world spots from incident_room.tscn. Each must get a
## distinct breathing phase, or the NPCs bob in lockstep and read as mannequins again.
const NPC_SPOTS := [
	Vector3(-4.11, 0.42, 5.4),
	Vector3(-8.18, 0.42, 3.43),
	Vector3(-5.02, 0.42, 0.46),
	Vector3(-2.29, 0.42, 1.38),
	Vector3(-1.16, 0.42, 2.39),
	Vector3(-8.35, 0.42, 0.37),
	Vector3(-2.0, 0.2, 6.4),
]

func run(_tree: SceneTree) -> Array[String]:
	var t = load("res://tests/test_support.gd").new()

	var seen := {}
	for pos in NPC_SPOTS:
		var ph: float = IdleBob.phase_for(pos)
		t.assert_true(ph >= 0.0 and ph < TAU, "phase in [0,TAU) for %s" % pos)
		t.assert_false(seen.has(ph), "phase is unique (no lockstep) for %s" % pos)
		seen[ph] = true

	# Deterministic per position → reproducible renders and no per-run flicker.
	t.assert_equal(IdleBob.phase_for(NPC_SPOTS[0]), IdleBob.phase_for(NPC_SPOTS[0]), "phase is deterministic per position")

	# DeskActivity typing motion (Phase 2): the offset must actually swing, and the two arms must
	# move in opposition, or the "typing" reads as both arms flapping together.
	t.assert_true(DeskActivity.offset(0.0, 9.0, false).is_equal_approx(Quaternion()), "offset at sin=0 is identity (no motion)")
	var peak := DeskActivity.offset(PI / 2.0, 9.0, false)
	t.assert_false(peak.is_equal_approx(Quaternion()), "offset swings away from rest mid-cycle")
	t.assert_true(peak.is_equal_approx(DeskActivity.offset(PI / 2.0, 9.0, true).inverse()), "alternate arm moves in opposition")

	return t.failures
