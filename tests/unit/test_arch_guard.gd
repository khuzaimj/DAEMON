extends GutTest

func test_core_classes_are_refcounted_and_pure() -> void:
	var dir: DirAccess = DirAccess.open("res://src/core")
	assert_not_null(dir, "res://src/core directory must exist")
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			var full_path: String = "res://src/core".path_join(file_name)
			var script: GDScript = load(full_path) as GDScript
			assert_not_null(script, "Should load script: " + full_path)
			var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
			var text: String = file.get_as_text()
			# Pure rules check:
			assert_false(text.contains("extends Node\n"), full_path + " must not extend Node")
			assert_false(text.contains("extends Node2D"), full_path + " must not extend Node2D")
			assert_false(text.contains("Input."), full_path + " must not access Input directly")
			assert_false(text.contains("get_tree()"), full_path + " must not access scene tree")
		file_name = dir.get_next()
	dir.list_dir_end()
