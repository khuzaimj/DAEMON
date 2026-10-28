extends Node

const SAVES_DIR: String = "user://saves"
const SETTINGS_PATH: String = "user://settings.json"

var current_slot: int = 1

func _ready() -> void:
	_ensure_saves_dir()

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

func get_slot_path(slot_idx: int) -> String:
	return "%s/slot%d.json" % [SAVES_DIR, slot_idx]

func save_slot(slot_idx: int) -> bool:
	_ensure_saves_dir()
	var game_node: Node = get_node_or_null("/root/Game")
	var world_node: Node = _find_world_node()

	var save_dict: Dictionary = SaveData.serialize(game_node, world_node)
	var path: String = get_slot_path(slot_idx)
	var success: bool = _write_atomic(path, save_dict)
	if success:
		current_slot = slot_idx
	return success

func load_slot(slot_idx: int) -> Dictionary:
	var path: String = get_slot_path(slot_idx)
	var data: Dictionary = _read_with_fallback(path)
	if data.is_empty():
		return {}
	return SaveData.deserialize(data)

func apply_save_to_game(data: Dictionary, world: Node = null) -> void:
	if data.is_empty():
		return

	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null:
		game_node.set("tick", int(data.get("playtime", 0)))
		game_node.set("scrap", int(data.get("scrap", 0)))

		var p: Dictionary = data.get("player", {}) as Dictionary
		game_node.set("clearance", int(p.get("clearance", 0)))
		game_node.set("garage_slots_cap", int(p.get("garage_slots", 3)))
		game_node.set("has_bus_pass", bool(p.get("has_bus_pass", false)))

		var reg: Array = []
		for m: Variant in p.get("registered_models", []):
			reg.append(str(m))
		game_node.set("registered_models", reg)

		var upg: Dictionary = p.get("upgrades", {}) as Dictionary
		var game_upg: Dictionary = game_node.get("upgrades") as Dictionary
		for k: Variant in upg.keys():
			game_upg[str(k)] = int(upg[k])

		var logs_arr: Array[String] = []
		for l: Variant in data.get("logs", []):
			logs_arr.append(str(l))
		game_node.set("logs", logs_arr)

		var m_dict: Dictionary = data.get("map", {}) as Dictionary
		var disc_arr: Array[String] = []
		for r: Variant in m_dict.get("discovered_rooms", []):
			disc_arr.append(str(r))
		game_node.set("discovered_rooms", disc_arr)

		var dock_arr: Array[String] = []
		for d: Variant in m_dict.get("visited_docks", []):
			dock_arr.append(str(d))
		game_node.set("visited_docks", dock_arr)

		var rooms_map: Dictionary = data.get("rooms", {}) as Dictionary
		var p_hosts: Dictionary = game_node.get("persistent_parked_hosts") as Dictionary
		p_hosts.clear()
		for r_key: Variant in rooms_map.keys():
			var r_entry: Dictionary = rooms_map[r_key] as Dictionary
			if r_entry.has("parked_hosts"):
				p_hosts[str(r_key)] = r_entry["parked_hosts"]

	var target_world: Node = world if world != null else _find_world_node()
	if target_world != null:
		var p_info: Dictionary = data.get("player", {}) as Dictionary
		var host_body: String = str(p_info.get("host_body", "cursor"))
		if target_world.has_method("swap_player_body"):
			target_world.call("swap_player_body", host_body)

		# Restore persistent latches in current room
		var cur_room: String = str(game_node.get("current_room_id")) if game_node != null else ""
		var rooms_dict: Dictionary = data.get("rooms", {}) as Dictionary
		if cur_room != "" and rooms_dict.has(cur_room):
			var r_delta: Dictionary = rooms_dict[cur_room] as Dictionary
			var latches: Dictionary = r_delta.get("latches", {}) as Dictionary
			if target_world.get("logic_system") != null:
				var l_sys: Object = target_world.get("logic_system")
				if l_sys != null and l_sys.has_method("restore_persistent_state"):
					l_sys.call("restore_persistent_state", latches)

func save_settings(settings: Dictionary) -> bool:
	return _write_atomic(SETTINGS_PATH, settings)

func load_settings() -> Dictionary:
	return _read_with_fallback(SETTINGS_PATH)

func _write_atomic(target_path: String, data: Dictionary) -> bool:
	var tmp_path: String = target_path + ".tmp"
	var bak_path: String = target_path + ".bak"

	var json_str: String = SaveData.to_json_string(data)

	# 1. Write to temp file
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		printerr("SaveSystem: Failed to open temp file for writing: " + tmp_path)
		return false
	file.store_string(json_str)
	file.close()

	# 2. Verify temp file parses correctly
	var verify_file: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		printerr("SaveSystem: Failed to open temp file for verification: " + tmp_path)
		return false
	var parsed: Variant = JSON.parse_string(verify_file.get_as_text())
	verify_file.close()
	if not (parsed is Dictionary):
		printerr("SaveSystem: Verification failed on temp file: " + tmp_path)
		DirAccess.remove_absolute(tmp_path)
		return false

	# 3. Rename old file to .bak if exists (Windows requires removing target before rename)
	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err: Error = DirAccess.rename_absolute(target_path, bak_path)
		if bak_err != OK:
			printerr("SaveSystem: Failed to backup old save file: %s -> %s" % [target_path, bak_path])

	# 4. Rename .tmp to target
	var rename_err: Error = DirAccess.rename_absolute(tmp_path, target_path)
	if rename_err != OK:
		printerr("SaveSystem: Failed to rename temp file to target: %s -> %s" % [tmp_path, target_path])
		if FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(bak_path, target_path)
		return false

	return true

func _read_with_fallback(target_path: String) -> Dictionary:
	var bak_path: String = target_path + ".bak"
	var paths_to_try: Array[String] = [target_path, bak_path]

	for path: String in paths_to_try:
		if not FileAccess.file_exists(path):
			continue
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text: String = f.get_as_text()
		f.close()
		var json: JSON = JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			return json.data as Dictionary

	return {}

func _find_world_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var cur: Node = tree.current_scene
	if cur is World:
		return cur
	if cur != null and cur.get("world") is World:
		return cur.get("world") as World
	return null
