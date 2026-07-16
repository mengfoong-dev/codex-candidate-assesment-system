class_name PlayerController
extends CharacterBody3D

signal interaction_requested(station_id: String)
signal nearest_station_changed(station_id: String)
signal hypothesis_requested

@export var movement_speed := 4.5
@export var camera_path: NodePath

@onready var player_visual: PlayerVisual = $Visual

var input_enabled := true
var _nearby_stations: Array[Area3D] = []
var _nearest_station_id := ""
# Click-to-walk target (point-and-click movement); WASD overrides it.
var _click_target := Vector3.ZERO
var _has_click_target := false
var _click_wants_interact := false
# Drag-to-orbit: a held drag rotates the camera; a small press+release is a tap (walk).
var _pointer_down := false
var _drag_dist := 0.0

func _unhandled_input(event: InputEvent) -> void:
    if not input_enabled:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
        var camera := get_node_or_null(camera_path)
        if camera != null and camera.has_method("toggle_mode"):
            camera.toggle_mode()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _pointer_down = true
            _drag_dist = 0.0
        else:
            _pointer_down = false
            if _drag_dist < 10.0:  # negligible movement => a tap, so walk there
                _walk_to_screen_point(event.position)
    elif event is InputEventMouseMotion and _pointer_down:
        # screen_relative is resolution-independent (unlike relative), so drag-look feels
        # consistent across the web canvas / HiDPI — Godot mouse-look best practice.
        var look: Vector2 = event.screen_relative
        _drag_dist += look.length()
        var camera := get_node_or_null(camera_path)
        if camera != null and camera.has_method("look_drag"):
            camera.look_drag(look)

func _walk_to_screen_point(screen_pos: Vector2) -> void:
    var camera := get_node_or_null(camera_path) as Camera3D
    if camera == null:
        return
    var origin := camera.project_ray_origin(screen_pos)
    var dir := camera.project_ray_normal(screen_pos)
    if absf(dir.y) < 0.0001:
        return
    var t := -origin.y / dir.y
    if t < 0.0:
        return
    var hit := origin + dir * t
    _click_target = Vector3(hit.x, 0.0, hit.z)
    _has_click_target = true
    # Walk to the tap point, then try to interact with whatever is there.
    _click_wants_interact = true

func _physics_process(_delta: float) -> void:
    if not input_enabled:
        velocity = Vector3.ZERO
        move_and_slide()
        player_visual.set_moving(false)
        return

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction := Vector3.ZERO
    if not input_vector.is_zero_approx():
        _has_click_target = false  # manual movement cancels a pending click
        direction = _camera_aligned_direction(input_vector)
    elif _has_click_target:
        var to_target := _click_target - global_position
        to_target.y = 0.0
        if to_target.length() > 0.3:
            direction = to_target.normalized()
        else:
            _has_click_target = false
            if _click_wants_interact:
                _click_wants_interact = false
                _request_nearest_station()
    velocity.x = direction.x * movement_speed
    velocity.z = direction.z * movement_speed
    if not is_on_floor():
        velocity.y -= 20.0 * get_physics_process_delta_time()
    else:
        velocity.y = 0.0
    move_and_slide()
    if direction.length_squared() > 0.01:
        rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.2)
    player_visual.set_moving(input_enabled and Vector2(velocity.x, velocity.z).length_squared() > 0.04)

    if Input.is_action_just_pressed("interact"):
        _request_nearest_station()
    if Input.is_action_just_pressed("quick_station_1"):
        interaction_requested.emit("observability_wall")
    if Input.is_action_just_pressed("quick_station_2"):
        interaction_requested.emit("developer_desk")
    if Input.is_action_just_pressed("quick_station_3"):
        interaction_requested.emit("release_console")
    if Input.is_action_just_pressed("open_hypothesis"):
        hypothesis_requested.emit()

func set_input_enabled(enabled: bool) -> void:
    input_enabled = enabled

func register_station(station: Area3D) -> void:
    if not _nearby_stations.has(station):
        _nearby_stations.append(station)
    _refresh_nearest_station()

func unregister_station(station: Area3D) -> void:
    _nearby_stations.erase(station)
    _refresh_nearest_station()

func _camera_aligned_direction(input_vector: Vector2) -> Vector3:
    if input_vector.is_zero_approx():
        return Vector3.ZERO
    var camera := get_node_or_null(camera_path) as Camera3D
    if camera == null:
        return Vector3(input_vector.x, 0.0, input_vector.y).normalized()
    var right := camera.global_basis.x
    var forward := -camera.global_basis.z
    right.y = 0.0
    forward.y = 0.0
    return (right.normalized() * input_vector.x - forward.normalized() * input_vector.y).normalized()

func _request_nearest_station() -> void:
    var nearest := _nearest_station()
    if nearest == null:
        return
    if nearest.has_method("request_interaction"):
        nearest.request_interaction()
    interaction_requested.emit(str(nearest.get("station_id")))

func _refresh_nearest_station() -> void:
    _nearby_stations = _nearby_stations.filter(func(station): return is_instance_valid(station))
    var nearest := _nearest_station()
    var next_id := "" if nearest == null else str(nearest.get("station_id"))
    if next_id != _nearest_station_id:
        _nearest_station_id = next_id
        nearest_station_changed.emit(_nearest_station_id)

func _nearest_station() -> Area3D:
    var nearest: Area3D = null
    var nearest_distance := INF
    for station: Area3D in _nearby_stations:
        var distance := global_position.distance_squared_to(station.global_position)
        if distance < nearest_distance:
            nearest = station
            nearest_distance = distance
    return nearest

