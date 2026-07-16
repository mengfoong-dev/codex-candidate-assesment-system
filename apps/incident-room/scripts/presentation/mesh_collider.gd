extends Node

## Generates trimesh static collision from a visual environment (e.g. the office GLB)
## so the player collides with the actual furniture/walls — obstacles to walk around —
## without hand-placing box colliders. Runs once at load.

@export var target_path: NodePath

func _ready() -> void:
    var target := get_node_or_null(target_path)
    if target == null:
        return
    for node: Node in target.find_children("*", "MeshInstance3D", true, false):
        (node as MeshInstance3D).create_trimesh_collision()
