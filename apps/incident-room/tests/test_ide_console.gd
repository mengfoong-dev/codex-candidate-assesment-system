extends RefCounted

## IDEConsole is presentation, but its two pure bits carry real risk: seeding the editor from the
## scenario source, and parsing/applying a fenced code block out of an assistant reply. Check both.

const IDEConsoleScene = preload("res://scenes/ui/ide_console.tscn")

func run(tree: SceneTree) -> Array[String]:
	var t = load("res://tests/test_support.gd").new()
	var console = IDEConsoleScene.instantiate()
	tree.root.add_child(console)          # runs _ready() -> seeds editor from the scenario

	# Seeded from the real scenario artifact, not empty / not the fallback-only case.
	t.assert_true(console._editor.text.contains("await"), "editor seeds with the incident source")
	t.assert_equal(console._file_rail.get_item_count(), 1, "one file listed in the rail")

	# A reply with a fenced block: prose is logged, the code replaces the editor buffer.
	var reply := "Parallelize the fetches.\n```ts\nconst x = await Promise.all([a(), b()]);\n```"
	t.assert_equal(console._extract_code(reply), "const x = await Promise.all([a(), b()]);", "extracts the fenced block")
	t.assert_equal(console._strip_code(reply), "Parallelize the fetches.", "prose is everything before the fence")
	console._busy = true                  # apply path early-returns unless a request is in flight
	console.apply_assistant_reply(reply)
	t.assert_true(console._editor.text.contains("Promise.all"), "codex edit applied into the editor")

	# A reply with no code block leaves the editor unchanged.
	var before: String = console._editor.text
	console._busy = true
	console.apply_assistant_reply("Looks fine to me.")
	t.assert_equal(console._editor.text, before, "no fenced block -> editor untouched")

	# reset() must wipe every per-candidate trace so the next session starts clean.
	console.reset()
	t.assert_equal(console._history.size(), 0, "reset clears chat history")
	t.assert_false(console._editor.text.contains("Promise.all"), "reset restores pristine source (prior edit gone)")
	t.assert_true(console._editor.text.contains("await"), "reset re-seeds the incident source")
	t.assert_false(console._busy, "reset clears the in-flight flag")

	console.queue_free()
	return t.failures
