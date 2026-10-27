class_name WorldGrid
extends RefCounted

static var _room_path_cache: Dictionary = {}

static func find_room_path(room_id: String) -> String:
	if _room_path_cache.has(room_id):
		return str(_room_path_cache[room_id])

	# 1. Try convention res://data/rooms/<zone>/<room_id>.json
	if "_" in room_id:
		var parts: PackedStringArray = room_id.split("_")
		var zone: String = parts[0]
		var candidate: String = "res://data/rooms/%s/%s.json" % [zone, room_id]
		if FileAccess.file_exists(candidate):
			_room_path_cache[room_id] = candidate
			return candidate

	# 2. Search all rooms under res://data/rooms
	var dir: DirAccess = DirAccess.open("res://data/rooms")
	if dir != null:
		dir.list_dir_begin()
		var sub: String = dir.get_next()
		while sub != "":
			if dir.current_is_dir() and sub != "." and sub != "..":
				var candidate: String = "res://data/rooms/%s/%s.json" % [sub, room_id]
				if FileAccess.file_exists(candidate):
					_room_path_cache[room_id] = candidate
					dir.list_dir_end()
					return candidate
			sub = dir.get_next()
		dir.list_dir_end()

	return ""

static func clear_cache() -> void:
	_room_path_cache.clear()
