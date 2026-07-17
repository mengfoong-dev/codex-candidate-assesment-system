class_name StationTrigger
extends Area3D

signal interaction_requested(station_id: String)

@export var station_id := ""
@export var station_title := "Station"
@export var accent_color := Color(0.2, 0.75, 0.95, 1.0)
## World-units above the trigger origin for the floating label. Stagger nearby stations
## (e.g. the desk vs. Sam) so their billboarded labels don't overlap on screen.
@export var label_height := 2.35
## Furniture/character meshes within this radius of the station light up when in range.
@export var highlight_radius := 1.3

@onready var station_label: Label3D = $StationLabel

var _landmark: Node = null
var _active := false
var _t := 0.0
var _overlay: StandardMaterial3D
var _highlight_meshes: Array[MeshInstance3D] = []
var _gathered := false

func _ready() -> void:
    station_label.text = station_title
    station_label.modulate = accent_color
    station_label.position.y = label_height
    _landmark = get_node_or_null("Landmark")
    var lm := _landmark as Node3D
    if lm != null:
        lm.position.y = label_height + 0.4  # pip floats just above the name tag
        if lm.has_method("set_color"):
            lm.call("set_color", accent_color)
    # Additive, unshaded overlay drawn over the object's own texture — brightens it in the
    # accent colour (a "glow") without replacing its material. Per-MeshInstance3D, so only
    # this station's object lights up. Alpha is pulsed in _process while in range.
    _overlay = StandardMaterial3D.new()
    _overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _overlay.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func request_interaction() -> void:
    interaction_requested.emit(station_id)

func _process(delta: float) -> void:
    if not _active or _overlay == null:
        return
    _t += delta
    var pulse := 0.5 + 0.5 * sin(_t * 5.0)
    _overlay.albedo_color.a = 0.32 + 0.34 * pulse

func _set_landmark_active(active: bool) -> void:
    _active = active
    if _landmark != null and _landmark.has_method("set_active"):
        _landmark.set_active(active)
    if active and not _gathered:
        _gather_highlight_meshes()
    for m in _highlight_meshes:
        if is_instance_valid(m):
            m.material_overlay = _overlay if active else null

## Collect nearby furniture/character meshes once, so activation just toggles their overlay.
## Skips the floor/walls/ceiling (by size) and the player's own body (a CharacterBody3D).
func _gather_highlight_meshes() -> void:
    _gathered = true
    var root: Node = get_tree().current_scene
    if root == null:
        root = get_tree().root
    var origin := global_position
    for n in root.find_children("*", "MeshInstance3D", true, false):
        var m := n as MeshInstance3D
        if _under_character_body(m):
            continue  # don't glow the player standing at the station
        var box := _world_box(m)
        var c: Vector3 = box[0]
        var sz: Vector3 = box[1]
        if maxf(sz.x, sz.z) > 2.5 or sz.y > 2.0 or c.y > 1.7:
            continue  # floor / walls / ceiling / big shells
        if Vector2(c.x - origin.x, c.z - origin.z).length() <= highlight_radius:
            _highlight_meshes.append(m)

func _under_character_body(node: Node) -> bool:
    var p := node.get_parent()
    while p != null:
        if p is CharacterBody3D:
            return true
        p = p.get_parent()
    return false

## World-space [center, size] of a mesh instance's AABB.
func _world_box(m: MeshInstance3D) -> Array:
    var ab := m.get_aabb()
    var gt := m.global_transform
    var wmin := Vector3(INF, INF, INF)
    var wmax := -wmin
    for i in 8:
        var corner := ab.position + Vector3(
            ab.size.x if (i & 1) else 0.0,
            ab.size.y if (i & 2) else 0.0,
            ab.size.z if (i & 4) else 0.0)
        var wp := gt * corner
        wmin = Vector3(minf(wmin.x, wp.x), minf(wmin.y, wp.y), minf(wmin.z, wp.z))
        wmax = Vector3(maxf(wmax.x, wp.x), maxf(wmax.y, wp.y), maxf(wmax.z, wp.z))
    return [(wmin + wmax) * 0.5, wmax - wmin]

func _on_body_entered(body: Node3D) -> void:
    if body.has_method("register_station"):
        body.register_station(self)
    _set_landmark_active(true)

func _on_body_exited(body: Node3D) -> void:
    if body.has_method("unregister_station"):
        body.unregister_station(self)
    _set_landmark_active(false)
