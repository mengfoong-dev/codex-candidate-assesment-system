extends RefCounted

const ROOM_PATH := "res://scenes/room/incident_room.tscn"
const PLAYER_SCRIPT_PATH := "res://scripts/presentation/player_controller.gd"
const REQUIRED_ACTIONS := [
    "move_forward",
    "move_backward",
    "move_left",
    "move_right",
    "interact",
    "quick_station_1",
    "quick_station_2",
    "quick_station_3",
    "open_hypothesis",
]

func run(tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var packed: PackedScene = load(ROOM_PATH)
    t.assert_true(packed != null, "incident room scene loads")
    if packed == null:
        return t.failures

    var room: Node = packed.instantiate()
    tree.root.add_child(room)
    t.assert_true(room is Node3D, "incident room root is Node3D")

    var cameras := room.find_children("*", "Camera3D", true, false)
    t.assert_equal(cameras.size(), 1, "room has exactly one camera")
    if cameras.size() == 1:
        t.assert_equal(cameras[0].projection, Camera3D.PROJECTION_ORTHOGONAL, "camera is orthographic")
        t.assert_true(cameras[0].current, "camera is current")

    var player := room.get_node_or_null("Player")
    t.assert_true(player is CharacterBody3D, "player is a CharacterBody3D")
    if player != null:
        t.assert_true(player.has_signal("interaction_requested"), "player emits station interaction intent")
        t.assert_true(player.has_signal("nearest_station_changed"), "player emits proximity changes")

    var floor := room.get_node_or_null("Architecture/Floor")
    t.assert_true(floor is StaticBody3D, "room has a collision floor")
    if floor != null:
        t.assert_true(floor.get_node_or_null("CollisionShape3D") is CollisionShape3D, "floor collision shape exists")

    var station_ids: Array[String] = []
    for area: Node in room.find_children("*", "Area3D", true, false):
        var station_id: Variant = area.get("station_id")
        if station_id != null and not str(station_id).is_empty():
            station_ids.append(str(station_id))
            t.assert_true(area.has_signal("interaction_requested"), "%s emits interaction intent" % station_id)
    station_ids.sort()
    t.assert_equal(station_ids, ["developer_desk", "observability_wall", "release_console"], "three stable station IDs")

    for action: String in REQUIRED_ACTIONS:
        t.assert_true(InputMap.has_action(action), "input action exists: %s" % action)

    var controller_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
    t.assert_false(controller_source.contains("CandidateSession"), "movement does not call candidate session")
    t.assert_false(controller_source.contains("EventLogger"), "movement does not call event logger")

    var shell := room.get_node_or_null("Architecture/CozyOfficeShell")
    t.assert_true(shell is Node3D, "room has the cozy office shell")
    var dressing := room.get_node_or_null("Dressing")
    t.assert_true(dressing is Node3D, "room has a furniture dressing layer")
    if dressing != null:
        var dressing_nodes := dressing.find_children("*", "Node3D", true, false)
        t.assert_true(dressing_nodes.size() >= 18, "dressing composes at least 18 furniture nodes")

    for node_name: String in ["ObservabilityWall", "DeveloperDesk", "ReleaseConsole"]:
        var station := room.get_node_or_null(node_name)
        t.assert_true(station is Area3D, "station present: %s" % node_name)
        if station == null:
            continue
        var landmark := station.get_node_or_null("Landmark")
        t.assert_true(landmark != null, "%s has a Landmark" % node_name)
        if landmark == null:
            continue
        t.assert_true(landmark.has_method("set_active"), "%s landmark exposes set_active" % node_name)
        for light: Node in landmark.find_children("*", "Light3D", true, false):
            t.assert_false((light as Light3D).shadow_enabled, "%s landmark light casts no shadow" % node_name)

    room.queue_free()
    return t.failures
