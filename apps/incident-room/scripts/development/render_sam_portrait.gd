extends SceneTree

# Throwaway: renders a headshot of Sam (character-male-a) to assets/ui/portrait_sam.png.
# Tweak the constants, re-run, eyeball. Deleted after the portrait looks right.

const MODEL := "res://assets/third_party/kenney-mini-characters/character-male-a.glb"
const OUT := "res://assets/ui/portrait_sam.png"
const SIZE := 512
const YAW_DEG := 0.0          # rotate model to face camera (+Z). Flip if we see its back.
const FRAME_TOP := 0.80       # look at this fraction up the model's height (head)
const FRAME_SPAN := 0.62      # vertical fraction of the model the camera should cover
const BG := Color(0.95, 0.93, 0.88, 1) # soft cream portrait backdrop

var _vp: SubViewport
var _frames := 0

func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.9)
	e.ambient_light_energy = 1.4
	env.environment = e
	_vp.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 1.3
	_vp.add_child(key)

	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.rotation_degrees = Vector3(0, YAW_DEG, 0)
	_vp.add_child(model)

	var cam := Camera3D.new()
	cam.fov = 35.0
	_vp.add_child(cam)
	cam.make_current()
	set_meta("model", model)
	set_meta("cam", cam)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _frames > 4:
		# Camera already placed on frame 4; give it a couple frames to render, then capture.
		if _frames < 7:
			return false
		var img2 := _vp.get_texture().get_image()
		img2.save_png(OUT)
		print("saved=%s" % OUT)
		quit()
		return true
	var model: Node3D = get_meta("model")
	var cam: Camera3D = get_meta("cam")
	# Merge AABBs of all mesh instances (world space).
	var meshes := model.find_children("*", "VisualInstance3D", true, false)
	var aabb := AABB()
	var first := true
	for m: Variant in meshes:
		var vi := m as VisualInstance3D
		var world := vi.global_transform * vi.get_aabb()
		if first:
			aabb = world
			first = false
		else:
			aabb = aabb.merge(world)
	if first:
		print("NO_MESHES")
		quit(1)
		return true
	var cx := aabb.position.x + aabb.size.x * 0.5
	var cz := aabb.position.z + aabb.size.z * 0.5
	var ty := aabb.position.y + aabb.size.y * FRAME_TOP
	var target := Vector3(cx, ty, cz)
	# Distance so the vertical span FRAME_SPAN*height fits the FOV.
	var span := aabb.size.y * FRAME_SPAN
	var dist := (span * 0.5) / tan(deg_to_rad(cam.fov) * 0.5) + aabb.size.z
	cam.global_transform = Transform3D(Basis.IDENTITY, target + Vector3(0, 0, dist)).looking_at(target, Vector3.UP)
	print("AABB pos=%v size=%v  target=%v dist=%.2f (camera placed)" % [aabb.position, aabb.size, target, dist])
	return false
