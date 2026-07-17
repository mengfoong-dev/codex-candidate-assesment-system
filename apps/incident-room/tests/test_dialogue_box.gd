extends RefCounted

## DialogueBox is presentation, but its line-stepping + finish logic is pure and worth a check:
## play() shows the first line, advancing mid-type reveals the whole line, and after the last
## line it hides and emits `finished` exactly once.

const DialogueBoxScript = preload("res://scripts/presentation/dialogue_box.gd")

var _finished := 0

func run(tree: SceneTree) -> Array[String]:
	var t = load("res://tests/test_support.gd").new()
	var box = DialogueBoxScript.new()
	tree.root.add_child(box)          # runs _ready() -> builds children
	box.finished.connect(func() -> void: _finished += 1)

	var lines := [
		{"speaker": "Sam", "text": "one", "portrait": null},
		{"speaker": "Sam", "text": "two", "portrait": null},
		{"speaker": "Sam", "text": "three", "portrait": null},
	]
	box.play(lines)
	t.assert_true(box.is_active(), "box is active after play")
	t.assert_equal(box._index, 0, "starts on the first line")
	t.assert_true(box._typing, "first line begins typing")
	t.assert_equal(box._body.visible_characters, 0, "first line starts fully hidden")

	# Advancing mid-type reveals the whole current line without skipping to the next.
	box.advance_line()
	t.assert_false(box._typing, "advance mid-type stops typing")
	t.assert_equal(box._body.visible_characters, -1, "advance mid-type reveals the full line")
	t.assert_equal(box._index, 0, "advance mid-type stays on the same line")

	# Now step through the remaining lines: each needs a reveal + a next.
	var guard := 0
	while box.is_active() and guard < 20:
		box.advance_line()
		guard += 1

	t.assert_false(box.is_active(), "box hides after the last line")
	t.assert_equal(_finished, 1, "finished emitted exactly once")

	box.queue_free()
	return t.failures
