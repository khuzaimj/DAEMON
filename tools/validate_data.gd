class_name ValidateData
extends SceneTree

const ROOM_WIDTH: int = 30
const ROOM_HEIGHT: int = 15

func _init() -> void:
	var error_count: int = 0
	var json_files: Array[String] = _get_files_recursive("res://data", [".json"])

	# 1. Parse all JSON files
	var parsed_data: Dictionary = {}
	for path: String in json_files:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("ERROR: Cannot open data file: " + path)
			error_count += 1
			continue
		var text: String = file.get_as_text()
		var json: JSON = JSON.new()
		var err: Error = json.parse(text)
		if err != OK:
			printerr("ERROR: Invalid JSON in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
			error_count += 1
		else:
			parsed_data[path] = json.data
			print("validate_data: OK " + path)

	# 2. Validate sizes.json
	var known_sizes: Array[String] = []
	if parsed_data.has("res://data/sizes.json"):
		var sizes_dict: Dictionary = parsed_data["res://data/sizes.json"] as Dictionary
		var size_errors: Array[String] = Schema.validate_sizes(sizes_dict, "res://data/sizes.json")
		for err_msg: String in size_errors:
			printerr("ERROR: " + err_msg)
			error_count += 1
		var sizes_map: Dictionary = sizes_dict.get("sizes", {})
		for s_key: Variant in sizes_map.keys():
			known_sizes.append(str(s_key).to_lower())
	else:
		printerr("ERROR: res://data/sizes.json not found")
		error_count += 1

	# 3. Validate tiles.json and extract glyphs
	var known_glyphs: Array[String] = []
	if parsed_data.has("res://data/tiles.json"):
		var tiles_root: Dictionary = parsed_data["res://data/tiles.json"] as Dictionary
		var tiles_dict: Dictionary = tiles_root.get("tiles", {})
		for g: Variant in tiles_dict.keys():
			known_glyphs.append(str(g))
	else:
		printerr("ERROR: res://data/tiles.json not found")
		error_count += 1

	# 4. Validate abilities (data/abilities/*.json)
	var known_abilities: Dictionary = {}
	for path: String in parsed_data.keys():
		if path.begins_with("res://data/abilities/") and path.ends_with(".json"):
			var ab_data: Dictionary = parsed_data[path] as Dictionary
			var ab_errors: Array[String] = Schema.validate_ability(ab_data, path)
			for err_msg: String in ab_errors:
				printerr("ERROR: " + err_msg)
				error_count += 1
			var ab_id: String = str(ab_data.get("id", ""))
			if not ab_id.is_empty():
				known_abilities[ab_id] = ab_data

	# 5. Validate bodies (data/bodies/*.json)
	var known_bodies: Dictionary = {}
	for path: String in parsed_data.keys():
		if path.begins_with("res://data/bodies/") and path.ends_with(".json"):
			var body_data: Dictionary = parsed_data[path] as Dictionary
			var body_errors: Array[String] = Schema.validate_body(body_data, path)
			for err_msg: String in body_errors:
				printerr("ERROR: " + err_msg)
				error_count += 1
			var b_id: String = str(body_data.get("id", ""))
			if not b_id.is_empty():
				known_bodies[b_id] = body_data

			# Size class check
			var size_val: String = str(body_data.get("size", "")).to_lower()
			if not known_sizes.has(size_val):
				printerr("ERROR: Body %s size '%s' not found in sizes.json" % [b_id, size_val])
				error_count += 1

			# Cross-reference abilities if abilities are loaded
			if known_abilities.size() > 0:
				var pri: String = str(body_data.get("primary", ""))
				if not pri.is_empty() and not known_abilities.has(pri):
					printerr("ERROR: Body %s primary ability '%s' not found in data/abilities/" % [b_id, pri])
					error_count += 1
				var sec: String = str(body_data.get("secondary", ""))
				if not sec.is_empty() and not known_abilities.has(sec):
					printerr("ERROR: Body %s secondary ability '%s' not found in data/abilities/" % [b_id, sec])
					error_count += 1

	# 6. Validate AI presets (data/ai/*.json)
	var known_ai: Dictionary = {}
	for path: String in parsed_data.keys():
		if path.begins_with("res://data/ai/") and path.ends_with(".json"):
			var ai_data: Dictionary = parsed_data[path] as Dictionary
			var ai_errors: Array[String] = Schema.validate_ai_preset(ai_data, path)
			for err_msg: String in ai_errors:
				printerr("ERROR: " + err_msg)
				error_count += 1
			var ai_id: String = str(ai_data.get("id", ""))
			if not ai_id.is_empty():
				known_ai[ai_id] = ai_data

	# 7. Validate enemies (data/enemies/*.json)
	for path: String in parsed_data.keys():
		if path.begins_with("res://data/enemies/") and path.ends_with(".json"):
			var enemy_data: Dictionary = parsed_data[path] as Dictionary
			var enemy_errors: Array[String] = Schema.validate_enemy(enemy_data, path)
			for err_msg: String in enemy_errors:
				printerr("ERROR: " + err_msg)
				error_count += 1
			var enemy_id: String = str(enemy_data.get("id", ""))
			var ref_body: String = str(enemy_data.get("body", ""))
			var ref_ai: String = str(enemy_data.get("ai", ""))

			if known_bodies.size() > 0 and not known_bodies.has(ref_body):
				printerr("ERROR: Enemy %s references non-existent body '%s'" % [enemy_id, ref_body])
				error_count += 1
			if known_ai.size() > 0 and not known_ai.has(ref_ai):
				printerr("ERROR: Enemy %s references non-existent AI '%s'" % [enemy_id, ref_ai])
				error_count += 1

	# 8. Validate bosses (data/bosses/*.json)
	for path: String in parsed_data.keys():
		if path.begins_with("res://data/bosses/") and path.ends_with(".json"):
			var boss_data: Dictionary = parsed_data[path] as Dictionary
			var boss_errors: Array[String] = Schema.validate_boss(boss_data, path)
			for err_msg: String in boss_errors:
				printerr("ERROR: " + err_msg)
				error_count += 1

	# 9. Collect and validate all room files
	var rooms_by_id: Dictionary = {}
	var room_paths: Dictionary = {}
	for path: String in parsed_data.keys():
		if path.begins_with("res://data/rooms/") and path.ends_with(".json"):
			var room_dict: Dictionary = parsed_data[path] as Dictionary
			var room_id: String = room_dict.get("id", "")
			if room_id == "":
				printerr("ERROR: Room missing 'id' in %s" % path)
				error_count += 1
				continue
			rooms_by_id[room_id] = room_dict
			room_paths[room_id] = path

			# Validate grid dimensions
			var raw_grid: Variant = room_dict.get("grid")
			if not (raw_grid is Array):
				printerr("ERROR: Room 'grid' must be Array in %s" % path)
				error_count += 1
				continue
			var rows: Array = raw_grid as Array
			if rows.size() != ROOM_HEIGHT:
				printerr("ERROR: Room %s grid height must be %d, got %d in %s" % [room_id, ROOM_HEIGHT, rows.size(), path])
				error_count += 1
				continue

			for y: int in range(rows.size()):
				var line: String = str(rows[y])
				if line.length() != ROOM_WIDTH:
					printerr("ERROR: Room %s row %d length must be %d, got %d in %s" % [room_id, y, ROOM_WIDTH, line.length(), path])
					error_count += 1
				# Verify all glyphs exist in tiles.json
				for x: int in range(line.length()):
					var glyph: String = line[x]
					if not known_glyphs.has(glyph):
						printerr("ERROR: Room %s row %d col %d has unknown glyph '%s' in %s" % [room_id, y, x, glyph, path])
						error_count += 1

			# Validate border openings vs declared exits
			var exits: Dictionary = room_dict.get("exits", {})
			# North border (row 0)
			var row0: String = str(rows[0])
			for x: int in range(row0.length()):
				if row0[x] != "#" and not exits.has("n"):
					printerr("ERROR: Room %s has open North border at col %d but no 'n' exit declared" % [room_id, x])
					error_count += 1
			# South border (row 14)
			var row14: String = str(rows[ROOM_HEIGHT - 1])
			for x: int in range(row14.length()):
				if row14[x] != "#" and not exits.has("s"):
					printerr("ERROR: Room %s has open South border at col %d but no 's' exit declared" % [room_id, x])
					error_count += 1
			# West border (col 0) & East border (col 29)
			for y: int in range(rows.size()):
				var r: String = str(rows[y])
				if r.length() > 0 and r[0] != "#" and not exits.has("w"):
					printerr("ERROR: Room %s has open West border at row %d but no 'w' exit declared" % [room_id, y])
					error_count += 1
				if r.length() >= ROOM_WIDTH and r[ROOM_WIDTH - 1] != "#" and not exits.has("e"):
					printerr("ERROR: Room %s has open East border at row %d but no 'e' exit declared" % [room_id, y])
					error_count += 1

	# 9. Validate neighbor exits match reciprocally
	var opp_dirs: Dictionary = { "n": "s", "s": "n", "e": "w", "w": "e" }
	for room_id: String in rooms_by_id:
		var room: Dictionary = rooms_by_id[room_id]
		var exits: Dictionary = room.get("exits", {})
		var grid: Array = room.get("grid", [])

		for dir_key: String in exits:
			var neighbor_id: String = str(exits[dir_key])
			if not rooms_by_id.has(neighbor_id):
				printerr("ERROR: Room %s exit '%s' points to non-existent room '%s'" % [room_id, dir_key, neighbor_id])
				error_count += 1
				continue

			var neighbor: Dictionary = rooms_by_id[neighbor_id]
			var neighbor_exits: Dictionary = neighbor.get("exits", {})
			var neighbor_grid: Array = neighbor.get("grid", [])
			var opp_dir: String = str(opp_dirs.get(dir_key, ""))

			if not neighbor_exits.has(opp_dir) or str(neighbor_exits[opp_dir]) != room_id:
				printerr("ERROR: Room %s exits '%s' to %s, but %s does not exit '%s' back to %s" % [room_id, dir_key, neighbor_id, neighbor_id, opp_dir, room_id])
				error_count += 1

			# Verify matching non-# border openings at same row/col
			if dir_key == "e":
				for y: int in range(ROOM_HEIGHT):
					var r_open: bool = (str(grid[y])[ROOM_WIDTH - 1] != "#")
					var n_open: bool = (str(neighbor_grid[y])[0] != "#")
					if r_open != n_open:
						printerr("ERROR: Mismatched East opening at row %d between %s and %s" % [y, room_id, neighbor_id])
						error_count += 1
			elif dir_key == "w":
				for y: int in range(ROOM_HEIGHT):
					var r_open: bool = (str(grid[y])[0] != "#")
					var n_open: bool = (str(neighbor_grid[y])[ROOM_WIDTH - 1] != "#")
					if r_open != n_open:
						printerr("ERROR: Mismatched West opening at row %d between %s and %s" % [y, room_id, neighbor_id])
						error_count += 1
			elif dir_key == "s":
				for x: int in range(ROOM_WIDTH):
					var r_open: bool = (str(grid[ROOM_HEIGHT - 1])[x] != "#")
					var n_open: bool = (str(neighbor_grid[0])[x] != "#")
					if r_open != n_open:
						printerr("ERROR: Mismatched South opening at col %d between %s and %s" % [x, room_id, neighbor_id])
						error_count += 1
			elif dir_key == "n":
				for x: int in range(ROOM_WIDTH):
					var r_open: bool = (str(grid[0])[x] != "#")
					var n_open: bool = (str(neighbor_grid[ROOM_HEIGHT - 1])[x] != "#")
					if r_open != n_open:
						printerr("ERROR: Mismatched North opening at col %d between %s and %s" % [x, room_id, neighbor_id])
						error_count += 1

	if error_count > 0:
		printerr("validate_data: failed with %d errors" % error_count)
		quit(1)
	else:
		print("validate_data: OK (%d JSON files verified, %d rooms verified with Validator v1)" % [json_files.size(), rooms_by_id.size()])
		quit(0)

func _get_files_recursive(dir_path: String, extensions: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path: String = dir_path.path_join(file_name)
			if dir.current_is_dir():
				result.append_array(_get_files_recursive(full_path, extensions))
			else:
				for ext: String in extensions:
					if file_name.ends_with(ext):
						result.append(full_path)
						break
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
