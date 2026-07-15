extends RefCounted

const REQUIRED_WEB_PRESET_FRAGMENTS: Array[String] = [
    "name=\"Web\"",
    "platform=\"Web\"",
    "export_path=\"dist/web/index.html\"",
    "variant/thread_support=false",
    "progressive_web_app/enabled=false",
]

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
    t.assert_true(not presets.is_empty(), "export presets load")
    for fragment: String in REQUIRED_WEB_PRESET_FRAGMENTS:
        t.assert_true(presets.contains(fragment), "Web preset contains %s" % fragment)
    return t.failures
