class_name PlayerController
extends CharacterBody3D

signal interaction_requested(station_id: String)
signal nearest_station_changed(station_id: String)
signal hypothesis_requested

@export var movement_speed := 4.5
@export var camera_path: NodePath

var input_enabled := true
var _nearby_stations: Array[Area3D] = []
var _nearest_station_id := ""

func _physics_process(_delta: float) -> void:
    if not input_enabled:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction := _camera_aligned_direction(input_vector)
    velocity.x = direction.x * movement_speed
    velocity.z = direction.z * movement_speed
    if not is_on_floor():
        velocity.y -= 20.0 * get_physics_process_delta_time()
    else:
        velocity.y = 0.0
    move_and_slide()
    if direction.length_squared() > 0.01:
        rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.2)

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

