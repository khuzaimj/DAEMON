class_name LoadAll
extends SceneTree

func _init() -> void:
	var error_count: int = 0
	var files: Array[String] = []
	files.append_array(_get_files_recursive("res://src", [".gd"]))
	files.append_array(_get_files_recursive("res://scenes", [".tscn"]))
	files.append_array(_get_files_recursive("res://tools", [".gd"]))

	for path: String in files:
		if path == "res://tools/load_all.gd":
			continue
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			printerr("ERROR: Failed to load resource: " + path)
			error_count += 1
		else:
			print("load_all: OK " + path)

	if error_count > 0:
		printerr("load_all: failed with %d errors" % error_count)
		quit(1)
	else:
		print("load_all: OK (all resources loaded successfully)")
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
