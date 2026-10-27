extends GutTest

func test_four_room_traversal() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	world.load_room("debug_01")

	assert_eq(world.current_room_id, "debug_01", "Initial room must be debug_01")
	assert_not_null(world.player_machine, "Player machine must exist")

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# Room history tracker
	var visited: Array[String] = ["debug_01"]
	world.room_entered.connect(func(id: String) -> void:
		visited.append(id)
	)

	# 1. Walk East from debug_01 to debug_02 (start pos (56, 120), East exit at x >= 480)
	# 424 px / 1.866 px/tick = ~228 ticks + 18 transition ticks
	script_ctrl.queue_move(Vector2(1, 0), 250)
	for _i: int in range(270):
		world._physics_process(1.0 / 60.0)
		if world.current_room_id == "debug_02" and not world.is_transitioning:
			break

	assert_eq(world.current_room_id, "debug_02", "Must transition to debug_02")

	# 2. Walk South from debug_02 to debug_03 (start pos (8, 120))
	# Walk East 240px to col 15 center (x=248) = 129 ticks
	# Walk South 120px to exit (y >= 240) = 66 ticks + 18 transition ticks
	script_ctrl.planned_moves.clear()
	script_ctrl.queue_move(Vector2(1, 0), 129)
	script_ctrl.queue_move(Vector2(0, 1), 75)
	for _i: int in range(240):
		world._physics_process(1.0 / 60.0)
		if world.current_room_id == "debug_03" and not world.is_transitioning:
			break

	assert_eq(world.current_room_id, "debug_03", "Must transition to debug_03")

	# 3. Walk West from debug_03 to debug_04 (start pos (248, 8))
	# Walk South 112px to row 7 center (y=120) = 60 ticks
	# Walk West 248px to exit (x < 0) = 135 ticks + 18 transition ticks
	script_ctrl.planned_moves.clear()
	script_ctrl.queue_move(Vector2(0, 1), 60)
	script_ctrl.queue_move(Vector2(-1, 0), 145)
	for _i: int in range(240):
		world._physics_process(1.0 / 60.0)
		if world.current_room_id == "debug_04" and not world.is_transitioning:
			break

	assert_eq(world.current_room_id, "debug_04", "Must transition to debug_04")
	assert_true(visited.has("debug_01"), "Visited debug_01")
	assert_true(visited.has("debug_02"), "Visited debug_02")
	assert_true(visited.has("debug_03"), "Visited debug_03")
	assert_true(visited.has("debug_04"), "Visited debug_04")
