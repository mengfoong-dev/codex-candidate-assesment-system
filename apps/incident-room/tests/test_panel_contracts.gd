extends RefCounted

const PANEL_CONTRACTS := [
    {
        "path": "res://scenes/ui/title_screen.tscn",
        "root_type": "Control",
        "visible": true,
        "signals": {"start_requested": 0},
        "configure_args": 1,
    },
    {
        "path": "res://scenes/ui/briefing_panel.tscn",
        "root_type": "Control",
        "visible": false,
        "signals": {"hypothesis_submitted": 2},
        "configure_args": 1,
    },
    {
        "path": "res://scenes/ui/investigation_panel.tscn",
        "root_type": "Control",
        "visible": false,
        "signals": {"artifact_viewed": 1, "ai_disposition_selected": 1},
        "configure_args": 3,
    },
    {
        "path": "res://scenes/ui/hypothesis_panel.tscn",
        "root_type": "Control",
        "visible": false,
        "signals": {"revision_submitted": 3},
        "configure_args": 2,
    },
    {
        "path": "res://scenes/ui/release_panel.tscn",
        "root_type": "Control",
        "visible": false,
        "signals": {"verification_requested": 2, "final_submission_requested": 1},
        "configure_args": 2,
    },
    {
        "path": "res://scenes/ui/unscored_summary.tscn",
        "root_type": "Control",
        "visible": false,
        "signals": {"restart_requested": 0},
        "configure_args": 1,
    },
]

func run(tree: SceneTree) -> Array[String]:
    var t = load("res://tests/test_support.gd").new()
    for contract: Dictionary in PANEL_CONTRACTS:
        var packed: PackedScene = load(contract.path)
        t.assert_true(packed != null, "%s loads" % contract.path)
        if packed == null:
            continue
        var panel: Node = packed.instantiate()
        tree.root.add_child(panel)
        t.assert_true(panel is Control, "%s root is %s" % [contract.path, contract.root_type])
        t.assert_equal(panel.visible, contract.visible, "%s initial visibility" % contract.path)
        t.assert_true(panel.has_method("configure"), "%s has configure" % contract.path)
        for signal_name: String in contract.signals:
            t.assert_true(panel.has_signal(signal_name), "%s has %s" % [contract.path, signal_name])
            t.assert_equal(_signal_argument_count(panel, signal_name), contract.signals[signal_name], "%s %s arguments" % [contract.path, signal_name])
        var focusable_controls := _interactive_controls(panel)
        t.assert_true(not focusable_controls.is_empty(), "%s has interactive controls" % contract.path)
        for control: Control in focusable_controls:
            t.assert_true(control.focus_mode != Control.FOCUS_NONE, "%s keyboard focus: %s" % [contract.path, control.name])
        panel.queue_free()

    _assert_configured_content(tree, t)
    return t.failures

func _assert_configured_content(tree: SceneTree, t: RefCounted) -> void:
    var loaded: Dictionary = ScenarioLoader.load_file("res://data/scenarios/homepage_latency_v1.json")
    t.assert_true(loaded.ok, "panel scenario loads")
    if not loaded.ok:
        return

    var title := _instantiate(tree, "res://scenes/ui/title_screen.tscn")
    title.configure(loaded.scenario.notices)
    t.assert_true(title.get_node("Margin/Layout/Notices").text.contains(loaded.scenario.notices.human_review), "title displays human-review notice")
    t.assert_true(title.get_node("Margin/Layout/Notices").text.contains(loaded.scenario.notices.limitations), "title displays limitations notice")

    var briefing := _instantiate(tree, "res://scenes/ui/briefing_panel.tscn")
    briefing.configure(loaded.scenario)
    t.assert_equal(briefing.get_node("Panel/Margin/Layout/Hypothesis").item_count, loaded.scenario.hypotheses.size(), "briefing hypothesis choices")
    t.assert_true(briefing.get_node("Panel/Margin/Layout/Confirm").disabled, "briefing confirmation starts disabled")

    var investigation := _instantiate(tree, "res://scenes/ui/investigation_panel.tscn")
    investigation.configure("observability_wall", loaded.scenario, {})
    t.assert_equal(investigation.get_node("Panel/Margin/Layout/Artifacts").get_child_count(), 3, "station artifact choices")

    var hypothesis := _instantiate(tree, "res://scenes/ui/hypothesis_panel.tscn")
    hypothesis.configure(loaded.scenario, {})
    t.assert_equal(hypothesis.get_node("Panel/Margin/Layout/Hypothesis").item_count, loaded.scenario.hypotheses.size(), "revision hypothesis choices")

    var release := _instantiate(tree, "res://scenes/ui/release_panel.tscn")
    release.configure(loaded.scenario, {})
    t.assert_true(release.get_node("Panel/Margin/Layout/Actions/Submit").disabled, "final submission starts disabled")

    var summary := _instantiate(tree, "res://scenes/ui/unscored_summary.tscn")
    summary.configure({
        "label": "Unscored prototype summary",
        "completed": true,
        "saved_to_disk": false,
        "persistence_warning": "Could not save to disk.",
        "initial_hypothesis": {},
        "final_hypothesis": {},
        "evidence_timeline": [],
        "ai_disposition": {},
        "verification_actions": [],
        "final_submission": {},
        "notices": loaded.scenario.notices,
    })
    t.assert_equal(summary.get_node("Panel/Margin/Layout/Heading").text, "Unscored prototype summary", "summary heading")
    t.assert_true(summary.get_node("Panel/Margin/Layout/Notices").text.contains(loaded.scenario.notices.human_review), "summary human-review notice")
    t.assert_true(summary.get_node("Panel/Margin/Layout/Notices").text.contains(loaded.scenario.notices.limitations), "summary limitations notice")

    for panel: Node in [title, briefing, investigation, hypothesis, release, summary]:
        panel.queue_free()

func _instantiate(tree: SceneTree, path: String) -> Node:
    var panel: Node = load(path).instantiate()
    tree.root.add_child(panel)
    return panel

func _signal_argument_count(node: Node, signal_name: String) -> int:
    for signal_info: Dictionary in node.get_signal_list():
        if signal_info.name == signal_name:
            return signal_info.args.size()
    return -1

func _interactive_controls(root: Node) -> Array[Control]:
    var controls: Array[Control] = []
    for child: Node in root.find_children("*", "Control", true, true):
        if child is BaseButton or child is Range or child is OptionButton or child is ItemList or child is TabContainer:
            controls.append(child)
    return controls
