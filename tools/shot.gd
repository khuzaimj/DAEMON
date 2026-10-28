class_name ShotTool
extends SceneTree

func _init() -> void:
	call_deferred("_run_shot")

func _run_shot() -> void:
	var target_rooms: Array[String] = []
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())

	for i: int in range(all_args.size()):
		var arg: String = all_args[i]
		if arg == "--room" and i + 1 < all_args.size():
			target_rooms.append(all_args[i + 1])
		elif arg.begins_with("--room="):
			target_rooms.append(arg.substr(7))
		elif arg == "--all":
			target_rooms.append_array(["debug_01", "debug_02", "debug_03", "debug_04", "debug_05", "debug_06", "debug_07", "debug_08", "debug_09", "debug_10"])

	if target_rooms.is_empty():
		target_rooms.append("debug_01")

	# Ensure shots directory exists
	var dir: DirAccess = DirAccess.open("res://")
	if dir != null and not dir.dir_exists("shots"):
		dir.make_dir("shots")

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	if world_scene == null:
		printerr("shot.gd: Cannot load scenes/world.tscn")
		quit(1)
		return

	var world: World = world_scene.instantiate() as World
	root.add_child(world)

	for room_id: String in target_rooms:
		world.load_room(room_id)
		# Wait 3 frames for rendering and layout to settle
		for _f: int in range(3):
			await process_frame

		var vp: Viewport = root.get_viewport()
		if vp != null:
			var tex: Texture2D = vp.get_texture()
			if tex != null:
				var img: Image = tex.get_image()
				if img != null:
					var out_path: String = "res://shots/%s.png" % room_id
					var abs_path: String = ProjectSettings.globalize_path(out_path)
					var err: Error = img.save_png(abs_path)
					if err == OK:
						print("shot.gd: OK saved " + out_path)
					else:
						printerr("shot.gd: Error saving %s: %d" % [out_path, err])

	world.queue_free()
	quit(0)
