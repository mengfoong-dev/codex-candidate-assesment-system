extends RefCounted

const REQUIRED_WEB_PRESET_FRAGMENTS: Array[String] = [
    "name=\"Web\"",
    "platform=\"Web\"",
    "export_path=\"dist/web/index.html\"",
    "variant/thread_support=false",
    "progressive_web_app/enabled=false",
]

const DEPLOYMENT_CONTRACTS := {
    "res://deploy/railway-web/Dockerfile": [
        "FROM caddy:2-alpine",
        "COPY site /srv",
    ],
    "res://deploy/railway-web/Caddyfile": [
        ":{$PORT:8080}",
        "root * /srv",
        "try_files {path} /index.html",
        "file_server",
    ],
    "res://deploy/railway-web/railway.json": [
        "\"builder\": \"DOCKERFILE\"",
        "\"healthcheckPath\": \"/\"",
    ],
}

func run(_tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
    t.assert_true(not presets.is_empty(), "export presets load")
    for fragment: String in REQUIRED_WEB_PRESET_FRAGMENTS:
        t.assert_true(presets.contains(fragment), "Web preset contains %s" % fragment)
    for path: String in DEPLOYMENT_CONTRACTS:
        var contents := FileAccess.get_file_as_string(path)
        t.assert_true(not contents.is_empty(), "%s loads" % path)
        for fragment: String in DEPLOYMENT_CONTRACTS[path]:
            t.assert_true(contents.contains(fragment), "%s contains %s" % [path, fragment])
    return t.failures
