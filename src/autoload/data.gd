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
	if json.parse(text) != OK:
		return null
	_cache[res_path] = json.data
	return json.data

func clear_cache() -> void:
	_cache.clear()
