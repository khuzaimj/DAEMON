extends Node

var _cache: Dictionary = {}

func get_json(res_path: String) -> Variant:
	if _cache.has(res_path):
		return _cache[res_path]
	if not FileAccess.file_exists(res_path):
		return null
	var file: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		printerr("Data: Error parsing %s at line %d: %s" % [res_path, json.get_error_line(), json.get_error_message()])
		return null
	_cache[res_path] = json.data
	return json.data

func clear_cache() -> void:
	_cache.clear()
