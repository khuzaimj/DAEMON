extends GutTest

func test_room_runtime_terrain_and_collision() -> void:
	var room_def: Dictionary = {
		"id": "test_room",
		"cell": [0, 0],
		"exits": { "e": "test_next" },
		"grid": [
			"##############################",
			"#............................#",
			"#..~~........................#",
			"#..oo........................#",
			"#..::........................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"##############################"
		]
	}
	var runtime: RoomRuntime = RoomRuntime.new()
	add_child_autofree(runtime)
	runtime.setup(room_def)

	# Terrain queries
	var wall_info: Dictionary = runtime.terrain_at(Vector2(8, 8)) # Cell (0, 0)
	assert_eq(wall_info.get("name"), "wall")
	assert_true(wall_info.get("solid", false))

	var floor_info: Dictionary = runtime.terrain_at(Vector2(24, 24)) # Cell (1, 1)
	assert_eq(floor_info.get("name"), "floor")

	var coolant_info: Dictionary = runtime.terrain_at(Vector2(56, 40)) # Cell (3, 2) is '~'
	assert_eq(coolant_info.get("medium"), "liquid")

	var pit_info: Dictionary = runtime.terrain_at(Vector2(56, 56)) # Cell (3, 3) is 'o'
	assert_eq(pit_info.get("medium"), "void")

	var conduit_info: Dictionary = runtime.terrain_at(Vector2(56, 72)) # Cell (3, 4) is ':'
	assert_eq(conduit_info.get("fits"), "xs")

	# Exit check
	var exit_id: String = runtime.get_exit_at(Vector2(475, 120))
	assert_eq(exit_id, "test_next")
