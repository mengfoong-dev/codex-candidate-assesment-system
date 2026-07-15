extends RefCounted

var failures: Array[String] = []

func assert_true(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func assert_false(value: bool, message: String) -> void:
    assert_true(not value, message)

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])

func assert_has_keys(value: Dictionary, keys: Array[String], message: String) -> void:
    for key in keys:
        if not value.has(key):
            failures.append("%s: missing key %s" % [message, key])
