extends RefCounted

const PLAYER_PATH := "res://scenes/player/player.tscn"

func run(tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var packed: PackedScene = load(PLAYER_PATH)
    t.assert_true(packed != null, "player scene loads")
    if packed == null:
        return t.failures

    var player: Node = packed.instantiate()
    tree.root.add_child(player)

    var visual := player.get_node_or_null("Visual")
    t.assert_true(visual != null, "player has a visual adapter")
    if visual != null:
        t.assert_true(visual.has_method("set_moving"), "visual adapter exposes set_moving")
        t.assert_true(visual.get_node_or_null("Character") != null, "visual contains the imported employee")
    t.assert_true(player.get_node_or_null("CollisionShape3D") is CollisionShape3D, "collision remains independent")
    t.assert_true(player.get_node_or_null("Body") == null, "prototype capsule body is removed")

    player.queue_free()
    return t.failures
