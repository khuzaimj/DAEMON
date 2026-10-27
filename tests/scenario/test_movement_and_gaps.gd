extends GutTest

func test_size_and_conduit_rules() -> void:
	# Build test room:
	# Col 4 (x=64..80): 1-tile conduit path:
	#   Row 1: '.' floor (y=16..32)
	#   Row 2: ':' conduit (y=32..48)
	#   Row 3: ':' conduit (y=48..64)
	#   Row 4: '.' floor (y=64..80)
	# Col 8 (x=128..144): 1-tile gap path:
	#   Row 1: '.' floor (y=16..32)
	#   Row 2: '.' 1-tile gap (y=32..48), flanked by walls '#' at col 7 and col 9
	#   Row 3: '.' 1-tile gap (y=48..64)
	#   Row 4: '.' floor (y=64..80)
	var room_def: Dictionary = {
		"id": "gap_test",
		"cell": [0, 0],
		"grid": [
			"##############################", # Row 0
			"#............................#", # Row 1: open corridor
			"####:###.#####################", # Row 2: col 4 is ':', col 8 is '.' (1-tile gap)
			"####:###.#####################", # Row 3: col 4 is ':', col 8 is '.'
			"#............................#", # Row 4: open corridor
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

	# 1. XS Machine (Cursor, 8px) at col 4 center (x=72, y=24) moving down through conduit
	var xs_machine: Machine = load("res://scenes/machine.tscn").instantiate() as Machine
	xs_machine.size_class = "xs"
	xs_machine.position = Vector2(72, 24)
	add_child_autofree(xs_machine)
	xs_machine.current_room = runtime
	var xs_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	xs_ctrl.queue_move(Vector2(0, 1), 30)
	xs_machine.controller = xs_ctrl

	for t: int in range(30):
		xs_machine.step_controller(t)
		xs_machine.step_movement(1.0 / 60.0)

	assert_gt(xs_machine.position.y, 60.0, "XS machine must pass through conduit")

	# 2. M Machine (14px) at col 4 center (x=72, y=24) moving down towards conduit
	var m_conduit_machine: Machine = load("res://scenes/machine.tscn").instantiate() as Machine
	m_conduit_machine.size_class = "m"
	m_conduit_machine.position = Vector2(72, 24)
	add_child_autofree(m_conduit_machine)
	m_conduit_machine.current_room = runtime
	var m_conduit_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	m_conduit_ctrl.queue_move(Vector2(0, 1), 30)
	m_conduit_machine.controller = m_conduit_ctrl

	for t: int in range(30):
		m_conduit_machine.step_controller(t)
		m_conduit_machine.step_movement(1.0 / 60.0)

	assert_lt(m_conduit_machine.position.y, 32.0, "M machine must be blocked by conduit gate")

	# 3. M Machine (14px) at col 8 center (x=136, y=24) moving down through 1-tile gap (16px)
	var m_gap_machine: Machine = load("res://scenes/machine.tscn").instantiate() as Machine
	m_gap_machine.size_class = "m"
	m_gap_machine.position = Vector2(136, 24)
	add_child_autofree(m_gap_machine)
	m_gap_machine.current_room = runtime
	var m_gap_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	m_gap_ctrl.queue_move(Vector2(0, 1), 30)
	m_gap_machine.controller = m_gap_ctrl

	for t: int in range(30):
		m_gap_machine.step_controller(t)
		m_gap_machine.step_movement(1.0 / 60.0)

	assert_gt(m_gap_machine.position.y, 60.0, "M machine (14px) must pass through 1-tile gap (16px)")

	# 4. L Machine (Loader, 24px) at col 8 center (x=136, y=24) moving down towards 1-tile gap (16px)
	var l_machine: Machine = load("res://scenes/machine.tscn").instantiate() as Machine
	l_machine.size_class = "l"
	l_machine.position = Vector2(136, 24)
	add_child_autofree(l_machine)
	l_machine.current_room = runtime
	var l_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	l_ctrl.queue_move(Vector2(0, 1), 30)
	l_machine.controller = l_ctrl

	for t: int in range(30):
		l_machine.step_controller(t)
		l_machine.step_movement(1.0 / 60.0)

	assert_lt(l_machine.position.y, 32.0, "L machine (24px) must be blocked by 1-tile gap (16px)")
