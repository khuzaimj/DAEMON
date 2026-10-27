class_name ValidateData
extends SceneTree

func _init() -> void:
	var error_count: int = 0
	var json_files: Array[String] = _get_files_recursive("res://data", [".json"])

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
			print("validate_data: OK " + path)

	if error_count > 0:
		printerr("validate_data: failed with %d errors" % error_count)
		quit(1)
	else:
		print("validate_data: OK (%d JSON files verified)" % json_files.size())
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
