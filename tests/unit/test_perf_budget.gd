extends GutTest

func test_perf_budget_and_debug_tools() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	world.load_room("debug_01")

	# 1. Profile 600 ticks of simulation (10 seconds of gameplay)
	var t_start: int = Time.get_ticks_usec()
	var max_tick_usec: int = 0
	for _i: int in range(600):
		var t0: int = Time.get_ticks_usec()
		world._physics_process(1.0 / 60.0)
		var tick_time: int = Time.get_ticks_usec() - t0
		if tick_time > max_tick_usec:
			max_tick_usec = tick_time

	var total_usec: int = Time.get_ticks_usec() - t_start
	var avg_ms: float = (float(total_usec) / 600.0) / 1000.0
	var max_ms: float = float(max_tick_usec) / 1000.0

	print("Performance Profile (600 ticks): avg=%.3f ms, max=%.3f ms (Budget: <= 4.0 ms)" % [avg_ms, max_ms])
	assert_lt(avg_ms, 4.0, "Average simulation tick time must be <= 4.0 ms per §2.15")

	# 2. Test F2 Debug Collisions
	world.toggle_debug_collisions()
	assert_true(world.show_debug_collisions, "F2 toggles debug collisions on")
	world.toggle_debug_collisions()
	assert_false(world.show_debug_collisions, "F2 toggles debug collisions off")

	# 3. Test F3 Performance Overlay
	world.toggle_perf_overlay()
	assert_true(world.show_perf_overlay, "F3 toggles perf overlay on")
	assert_true(world.perf_overlay.visible, "Perf overlay visible")
	world.toggle_perf_overlay()
	assert_false(world.show_perf_overlay, "F3 toggles perf overlay off")

	# 4. Test F6 Warp Dialog
	world.toggle_warp_dialog()
	assert_true(world.warp_dialog.visible, "F6 toggles warp dialog on")
	world._on_warp_submitted("debug_02")
	assert_eq(world.current_room_id, "debug_02", "Warp moves to debug_02")
	assert_false(world.warp_dialog.visible, "Warp dialog closes on submit")

	# 5. Test F10 Input Recorder
	world.toggle_input_recording()
	assert_true(world.is_recording_input, "F10 toggles input recording on")
	# Step 5 ticks
	for _i: int in range(5):
		world._physics_process(1.0 / 60.0)
	assert_gt(world.recorded_input_stream.size(), 0, "Input recorder captured ticks")
	world.toggle_input_recording()
	assert_false(world.is_recording_input, "F10 toggles input recording off")
	assert_true(FileAccess.file_exists("user://input_record.json"), "user://input_record.json created")
