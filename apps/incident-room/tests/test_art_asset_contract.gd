extends RefCounted

const MANIFEST_PATH := "res://assets/third_party/asset_manifest.json"
const REQUIRED_FILES := [
    "res://assets/third_party/kaykit-furniture-bits/LICENSE.txt",
    "res://assets/third_party/kaykit-furniture-bits/furniturebits_texture.png",
    "res://assets/third_party/kaykit-furniture-bits/table_medium_long.gltf",
    "res://assets/third_party/kaykit-furniture-bits/table_medium_long.bin",
    "res://assets/third_party/kaykit-furniture-bits/chair_C.gltf",
    "res://assets/third_party/kaykit-furniture-bits/chair_C.bin",
    "res://assets/third_party/kaykit-furniture-bits/shelf_B_large_decorated.gltf",
    "res://assets/third_party/kaykit-furniture-bits/shelf_B_large_decorated.bin",
    "res://assets/third_party/kenney-mini-characters/LICENSE.txt",
    "res://assets/third_party/kenney-mini-characters/character-female-a.glb",
]

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    t.assert_true(FileAccess.file_exists(MANIFEST_PATH), "art asset manifest exists")
    if not FileAccess.file_exists(MANIFEST_PATH):
        return t.failures
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    t.assert_true(parsed is Dictionary, "art asset manifest is a JSON object")
    if parsed is Dictionary:
        t.assert_equal(parsed.get("schema_version"), 1, "manifest schema version")
        t.assert_equal(parsed.get("packs", []).size(), 2, "two CC0 packs recorded")
    for path: String in REQUIRED_FILES:
        t.assert_true(FileAccess.file_exists(path), "required art asset exists: %s" % path)
    var notices := FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md")
    t.assert_true(notices.contains("KayKit: Furniture Bits 1.0"), "KayKit notice recorded")
    t.assert_true(notices.contains("Kenney Mini Characters 1.0"), "Kenney notice recorded")
    return t.failures
