extends StaticBody3D
## Procedurally adds box collision to the office's interior wall panels so the player can't
## walk through partitions. The scene only hand-authors the perimeter walls + desks; the GLB's
## interior walls (front/back divider, corner room, back dividers) had none.
##
## One box per wall-panel mesh, so gaps between panels (doorways) stay open automatically.
## Only tall, thin panels count — furniture is shorter or not thin, so it is skipped. The
## whole-room shell mesh is skipped too (the perimeter boxes cover it).

@export var office_path: NodePath
@export var min_height := 1.4       ## a wall panel is at least this tall
@export var max_thickness := 0.5    ## a thin panel is at most this in one horizontal axis
@export var long_wall_min := 2.0    ## a long slab this wide counts as a wall even if chunky
@export var chunky_thickness := 1.3 ## ...as long as it is still no thicker than this (e.g. an L-corner)
@export var shell_span := 6.0       ## a mesh larger than this on BOTH X and Z is the room shell

func _ready() -> void:
	var office := get_node_or_null(office_path) as Node3D
	if office == null:
		push_warning("wall_collision: office_path not found")
		return
	var added := 0
	for node in office.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var size_and_center := _world_box(m)
		var size: Vector3 = size_and_center[0]
		if size.y < min_height:
			continue
		if size.x > shell_span and size.z > shell_span:
			continue  # whole-room shell — perimeter boxes cover it
		var thin: float = minf(size.x, size.z)
		var long_side: float = maxf(size.x, size.z)
		# A wall is a thin panel, OR a long slab that is still not blocky (an L-corner wall).
		# Compact tall furniture (roughly square footprint) is left alone.
		var is_wall := thin <= max_thickness or (long_side >= long_wall_min and thin <= chunky_thickness)
		if not is_wall:
			continue
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		add_child(cs)
		cs.global_position = size_and_center[1]
		added += 1
	if added == 0:
		push_warning("wall_collision: no wall panels found under %s" % office_path)

## World-space axis-aligned [size, center] of a mesh instance's AABB.
func _world_box(m: MeshInstance3D) -> Array:
	var aabb := m.get_aabb()
	var gt := m.global_transform
	var wmin := Vector3(INF, INF, INF)
	var wmax := -wmin
	for i in 8:
		var corner := aabb.position + Vector3(
			aabb.size.x if (i & 1) else 0.0,
			aabb.size.y if (i & 2) else 0.0,
			aabb.size.z if (i & 4) else 0.0)
		var wp := gt * corner
		wmin = Vector3(minf(wmin.x, wp.x), minf(wmin.y, wp.y), minf(wmin.z, wp.z))
		wmax = Vector3(maxf(wmax.x, wp.x), maxf(wmax.y, wp.y), maxf(wmax.z, wp.z))
	return [wmax - wmin, (wmin + wmax) * 0.5]
