class_name RoomLoader
extends RefCounted

static func load_room(res_path: String) -> Dictionary:
	var raw: Variant = _get_json_data(res_path)
	if raw == null or not (raw is Dictionary):
		return {}
	var room: Dictionary = raw as Dictionary
	if not _validate_room_structure(room, res_path):
		return {}
	return room

static func _get_json_data(res_path: String) -> Variant:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var root: Window = (main_loop as SceneTree).root
		if root != null:
			var data_node: Node = root.get_node_or_null("Data")
			if data_node != null and data_node.has_method("get_json"):
				return data_node.call("get_json", res_path)
	# Standalone fallback
	if not FileAccess.file_exists(res_path):
		return null
	var file: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return null
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data

static func _validate_room_structure(room: Dictionary, path: String) -> bool:
	if not room.has("id") or not room.has("grid"):
		printerr("RoomLoader: Missing 'id' or 'grid' in " + path)
		return false
	var grid: Variant = room.get("grid")
	if not (grid is Array):
		printerr("RoomLoader: 'grid' must be an Array in " + path)
		return false
	var rows: Array = grid as Array
	if rows.size() != Grid.ROOM_TILES_HEIGHT:
		printerr("RoomLoader: 'grid' row count must be %d, got %d in %s" % [Grid.ROOM_TILES_HEIGHT, rows.size(), path])
		return false
	for y: int in range(rows.size()):
		var line: String = str(rows[y])
		if line.length() != Grid.ROOM_TILES_WIDTH:
			printerr("RoomLoader: Row %d must have width %d, got %d in %s" % [y, Grid.ROOM_TILES_WIDTH, line.length(), path])
			return false
	return true
