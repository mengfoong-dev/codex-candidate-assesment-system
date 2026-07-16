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
        t.assert_equal(cameras[0].projection, Camera3D.PROJECTION_PERSPECTIVE, "third-person camera is perspective")
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

    # Any interactable in the room must expose the interaction signal the coordinator wires.
    for area: Node in room.find_children("*", "Area3D", true, false):
        var station_id: Variant = area.get("station_id")
        if station_id != null and not str(station_id).is_empty():
            t.assert_true(area.has_signal("interaction_requested"), "%s emits interaction intent" % station_id)

    for action: String in REQUIRED_ACTIONS:
        t.assert_true(InputMap.has_action(action), "input action exists: %s" % action)

    var controller_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
    t.assert_false(controller_source.contains("CandidateSession"), "movement does not call candidate session")
    t.assert_false(controller_source.contains("EventLogger"), "movement does not call event logger")

    # Decluttered office: the shell plus a single desk workstation and the senior NPC.
    t.assert_true(room.get_node_or_null("Architecture/CozyOfficeShell") is Node3D, "room has the cozy office shell")
    t.assert_true(room.get_node_or_null("MyDesk") is Node3D, "room has the player's desk workstation")
    t.assert_true(room.get_node_or_null("Senior") is Node3D, "room has the senior NPC")

    room.queue_free()
    return t.failures
