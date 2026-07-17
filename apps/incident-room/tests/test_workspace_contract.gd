extends RefCounted

const WORKSPACE_PATH := "res://scenes/ui/browser_workspace.tscn"
const TITLE_PATH := "res://scenes/ui/title_screen.tscn"
const WORKSPACE_SIGNALS := [
    "initial_hypothesis_submitted",
    "evidence_view_requested",
    "disposition_submitted",
    "verification_requested",
    "revision_submitted",
    "final_submission_requested",
    "restart_requested",
    "sandbox_test_requested",
]

func run(tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(loaded.ok, "workspace scenario loads")
    if not loaded.ok:
        return t.failures

    _assert_title(tree, t, loaded.scenario)
    _assert_workspace(tree, t, loaded.scenario)
    return t.failures

func _assert_title(tree: SceneTree, t: RefCounted, scenario: Dictionary) -> void:
    var packed: PackedScene = load(TITLE_PATH)
    t.assert_true(packed != null, "title scene loads")
    if packed == null:
        return
    var title: Node = packed.instantiate()
    tree.root.add_child(title)
    t.assert_true(title is Control, "title root is Control")
    t.assert_true(title.has_signal("start_requested"), "title emits start_requested")
    t.assert_true(title.has_method("configure"), "title has configure")
    title.configure(scenario.get("notices", {}))
    for control: Control in _interactive_controls(title):
        t.assert_true(control.focus_mode != Control.FOCUS_NONE, "title keyboard focus: %s" % control.name)
    title.queue_free()

func _assert_workspace(tree: SceneTree, t: RefCounted, scenario: Dictionary) -> void:
    var packed: PackedScene = load(WORKSPACE_PATH)
    t.assert_true(packed != null, "workspace scene loads")
    if packed == null:
        return
    var workspace: Node = packed.instantiate()
    tree.root.add_child(workspace)
    t.assert_true(workspace is Control, "workspace root is Control")
    for signal_name: String in WORKSPACE_SIGNALS:
        t.assert_true(workspace.has_signal(signal_name), "workspace emits %s" % signal_name)
    for method_name: String in ["configure", "set_started", "refresh", "show_report", "set_active_tab"]:
        t.assert_true(workspace.has_method(method_name), "workspace has %s" % method_name)

    workspace.configure(scenario)
    var tabs := workspace.get_node("Frame/TabStrip/Tabs")
    t.assert_true(tabs.get_child_count() >= 5, "workspace builds the candidate tabs")
    var has_codex_tab := false
    var has_workspace_tab := false
    for child: Node in tabs.get_children():
        if child is Button and (child as Button).text == "Codex":
            has_codex_tab = true
        if child is Button and (child as Button).text == "Workspace":
            has_workspace_tab = true
    t.assert_true(has_codex_tab, "workspace has the single Codex AI tab")
    t.assert_true(has_workspace_tab, "workspace has the simplified workspace tab")

    # Brief tab exposes every hypothesis; Submit tab exposes the submission options.
    workspace.set_started(true)
    workspace.refresh({
        "initial_hypothesis": {},
        "current_hypothesis": {},
        "viewed_artifact_ids": [],
        "ai_disposition_id": "",
        "verification_actions": [],
    })
    var focusable := _interactive_controls(workspace)
    t.assert_true(focusable.size() >= 5, "workspace has interactive controls")
    for control: Control in focusable:
        t.assert_true(control.focus_mode != Control.FOCUS_NONE, "workspace keyboard focus: %s" % control.name)

    # Evidence renders scenario artifacts; the workspace presents one clear file/edit/test flow.
    var host := workspace.get_node("Frame/Content/PanelHost")
    var text_blob := _collect_text(host)
    for artifact: Dictionary in scenario.get("artifacts", []):
        t.assert_true(text_blob.contains(str(artifact.get("title", ""))), "evidence lists artifact: %s" % artifact.get("title", ""))
    t.assert_true(text_blob.contains("src/watch_page_orchestrator.ts"), "workspace lists the editable incident file")
    t.assert_true(text_blob.contains("Run sandbox tests"), "workspace exposes the real sandbox test action")
    t.assert_false(text_blob.contains("Remediation to validate"), "workspace removes the old remediation-driven test UI")
    workspace.queue_free()

func _interactive_controls(root: Node) -> Array[Control]:
    var controls: Array[Control] = []
    for child: Node in root.find_children("*", "Control", true, false):
        if child is ScrollBar:
            continue
        if child is BaseButton or child is ItemList or child is HSlider or child is TextEdit:
            controls.append(child)
    return controls

func _collect_text(root: Node) -> String:
    var parts := PackedStringArray()
    for child: Node in root.find_children("*", "Control", true, false):
        if child is Label:
            parts.append((child as Label).text)
        elif child is Button:
            parts.append((child as Button).text)
        elif child is RichTextLabel:
            parts.append((child as RichTextLabel).text)
    return "\n".join(parts)
