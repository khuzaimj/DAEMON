class_name Schema
extends RefCounted

static func validate_keys(data: Dictionary, allowed_keys: Array[String], context: String = "") -> Array[String]:
	var errors: Array[String] = []
	for k: Variant in data.keys():
		var key_str: String = str(k)
		if key_str.begins_with("_"):
			continue
		if not allowed_keys.has(key_str):
			errors.append("%s: unknown key '%s'" % [context, key_str])
	return errors

static func is_snake_case(id: String) -> bool:
	var regex: RegEx = RegEx.new()
	var compile_err: Error = regex.compile("^[a-z0-9]+(_[a-z0-9]+)*$")
	if compile_err != OK:
		return false
	return regex.search(id) != null
