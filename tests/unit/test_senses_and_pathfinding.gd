extends GutTest

func test_senses_vision_cone_and_hearing() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	await get_tree().physics_frame

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")

	# Enemy machine at (100, 100), facing DOWN (South)
	var enemy: Machine = machine_scene.instantiate() as Machine
	enemy.position = Vector2(100, 100)
	enemy.facing = Vector2.DOWN
	enemy.operational_state = "hostile"
	enemy.enemy_data = {
		"senses": { "vision": 5.0, "hearing": 3.0, "fov_deg": 90.0 }
	}
	var ai_ctrl: AIController = AIController.new()
	enemy.controller = ai_ctrl
	enemy.add_child(ai_ctrl)
	world.entities_container.add_child(enemy)
	world.register_machine(enemy)

	# Target 1: player directly in front (100, 140) -> 40px away, within vision (80px) and in FOV
	var target: Machine = machine_scene.instantiate() as Machine
	target.position = Vector2(100, 140)
	target.operational_state = "player"
	world.entities_container.add_child(target)
	world.register_machine(target)
	world.player_machine = target

	var senses: SensesSystem = SensesSystem.new()
	senses.step(world, 1, 0.0166)

	assert_true(ai_ctrl.can_see_target, "Target directly in front should be seen")
	assert_true(ai_ctrl.can_hear_target, "Target within 48px should be heard")

	# Move target behind enemy (100, 60) -> 40px away (within hearing, but outside vision FOV)
	target.position = Vector2(100, 60)
	senses.step(world, 2, 0.0166)

	assert_false(ai_ctrl.can_see_target, "Target behind facing should not be seen")
	assert_true(ai_ctrl.can_hear_target, "Target within hearing radius should still be heard")

	# Move target far away (100, 300) -> 200px away (beyond vision and hearing)
	target.position = Vector2(100, 300)
	senses.step(world, 3, 0.0166)

	assert_false(ai_ctrl.can_see_target, "Target far away should not be seen")
	assert_false(ai_ctrl.can_hear_target, "Target far away should not be heard")

func test_pathfinding_large_size_and_hover() -> void:
	# Build a synthetic room grid with a 1-tile gap and a pit
	# Row 0: all solid
	# Row 1: #..#..o..# (walls, open paths, pit)
	# Row 2: #.##..o..# (Row 2 has a 1-tile corridor at col 1 between wall col 0 and wall col 2)
	var synthetic_grid: Array[String] = [
		"##############################",
		"#....#...o...#...............#",
		"#.##.#...o...#...............#",
		"#....#...o...#...............#",
		"##############################"
	]
	while synthetic_grid.size() < 15:
		synthetic_grid.append("##############################")

	var room_data: Dictionary = {
		"id": "test_room",
		"grid": synthetic_grid,
		"exits": {}
	}
	var room: RoomRuntime = RoomRuntime.new()
	add_child_autofree(room)
	room.setup(room_data)

	var pf: PathfindingSystem = PathfindingSystem.new()
	pf.setup_room(room)

	# 1. Size M (medium) navigating 1-tile corridor at (1, 1) to (1, 3)
	var path_m: PackedVector2Array = pf.find_path(Vector2(24, 24), Vector2(24, 56), "m", ["ground"])
	assert_gt(path_m.size(), 0, "Medium size machine can navigate 1-tile wide gap")

	# 2. Size L (Loader, 24px wide) attempting 1-tile corridor at (1, 1) to (1, 3)
	# Per Guardrail 5, 1-tile choke points are marked solid on ground_l!
	var grid_l: AStarGrid2D = pf.grids["ground_l"] as AStarGrid2D
	assert_true(grid_l.is_point_solid(Vector2i(1, 2)), "Col 1 Row 2 between walls at col 0 and col 2 must be solid for L size")

	# 3. Pit tile at (9, 1):
	# On ground grid, pit is solid
	var grid_ground: AStarGrid2D = pf.grids["ground_default"] as AStarGrid2D
	assert_true(grid_ground.is_point_solid(Vector2i(9, 1)), "Pit 'o' must be solid on ground grid")

	# On hover grid (Drone), pit is walkable per Guardrail 5
	var grid_hover: AStarGrid2D = pf.grids["hover"] as AStarGrid2D
	assert_false(grid_hover.is_point_solid(Vector2i(9, 1)), "Pit 'o' must be walkable on hover grid")
