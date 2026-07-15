extends SceneTree

func _initialize() -> void:
    call_deferred("_run_all")

func _run_all() -> void:
    var failure_count := 0
    var suite_files := PackedStringArray()
    for file_name in DirAccess.get_files_at("res://tests"):
        if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_support.gd":
            suite_files.append(file_name)
    suite_files.sort()
    for file_name in suite_files:
        var suite_script: Script = load("res://tests/" + file_name)
        if suite_script == null or not suite_script.can_instantiate():
            failure_count += 1
            push_error("%s: suite could not be loaded" % file_name)
            continue
        var suite_instance: RefCounted = suite_script.new()
        if not suite_instance.has_method("run"):
            failure_count += 1
            push_error("%s: suite has no run(tree) method" % file_name)
            continue
        var suite_failures: Array[String] = suite_instance.run(self)
        for failure in suite_failures:
            failure_count += 1
            push_error("%s: %s" % [file_name, failure])
    if failure_count > 0:
        print("TESTS FAILED: %d failures" % failure_count)
        quit(1)
    else:
        print("TESTS PASSED: %d suites" % suite_files.size())
        quit(0)
