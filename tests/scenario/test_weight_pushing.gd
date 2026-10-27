extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_01")

func test_weight_pushing_between_machines() -> void:
	# Heavy machine (Loader: weight 3)
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var heavy: Machine = machine_scene.instantiate() as Machine
	heavy.body_id = "loader"
	heavy.size_class = "l"
	heavy.weight = 3
	heavy.base_speed_tiles = 3.0
	heavy.position = Vector2(100, 100)
	world.entities_container.add_child(heavy)
	world.machines.append(heavy)

	# Light machine (weight 0) directly to the right of heavy machine
	var light: Machine = machine_scene.instantiate() as Machine
	light.body_id = "cursor"
	light.size_class = "xs"
	light.weight = 0
	light.base_speed_tiles = 0.0
	light.position = Vector2(120, 100)
	world.entities_container.add_child(light)
	world.machines.append(light)

	var start_light_x: float = light.position.x

	# Heavy moves right toward light machine
	heavy.current_intent.move = Vector2.RIGHT
	for i: int in range(30):
		heavy.step_movement(1.0 / 60.0)

	assert_gt(light.position.x, start_light_x, "Heavy machine (weight 3) must push light machine (weight 0)")

	# Now test that light machine moving left does NOT push heavy machine
	var heavy_pos_x: float = heavy.position.x
	light.weight = 0
	light.current_intent.move = Vector2.LEFT
	for i: int in range(30):
		light.step_movement(1.0 / 60.0)

	assert_almost_eq(heavy.position.x, heavy_pos_x, 0.5, "Light machine cannot push heavy machine")

func test_courier_dash_across_pit_and_void_expiry() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var courier: Machine = machine_scene.instantiate() as Machine
	courier.body_id = "courier"
	courier.size_class = "s"
	courier.weight = 0
	courier.current_room = world.active_room
	courier.position = Vector2(50, 100)
	world.entities_container.add_child(courier)
	world.machines.append(courier)

	# Dash across 3 tiles (48 px) at 16 tiles/s (256 px/s) for 11 ticks
	MovementAbilities.start_dash(courier, {
		"params": { "distance": 3.0, "duration": 0.18 }
	}, Vector2.RIGHT)

	assert_true(courier.is_dashing, "Courier should be dashing")
	assert_gt(courier.state.invulnerability_ticks, 0, "Dash provides invulnerability")

	# Step through dash
	for i: int in range(12):
		courier.step_movement(1.0 / 60.0)

	assert_false(courier.is_dashing, "Dash should end after ticks expire")
	assert_almost_eq(courier.position.x, 50.0 + 48.0, 4.0, "Courier traversed 48px dash distance")
