extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05") # Load Body Range room

func test_all_10_bodies_scenario() -> void:
	var body_ids: Array[String] = [
		"cursor", "janitor", "loader", "sentry", "drone",
		"welder", "diver", "crawler", "courier", "medic"
	]
	
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var machine: Machine = machine_scene.instantiate() as Machine
	world.entities_container.add_child(machine)
	world.machines.append(machine)
	machine.current_room = world.active_room
	machine.position = Vector2(50, 50)
	
	for b_id: String in body_ids:
		var file_path: String = "res://data/bodies/%s.json" % b_id
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		assert_not_null(file, "Body file must exist: " + file_path)
		var json: JSON = JSON.new()
		assert_eq(json.parse(file.get_as_text()), OK)
		var body_data: Dictionary = json.data as Dictionary
		
		machine.apply_body_data(body_data)
		assert_eq(machine.body_id, b_id, "Machine body_id should match " + b_id)
		assert_eq(machine.state.current_integrity, machine.state.max_integrity)
		
		# Test movement
		machine.current_intent.move = Vector2.RIGHT
		var start_x: float = machine.position.x
		machine.step_movement(1.0 / 60.0)
		
		if b_id == "sentry":
			assert_almost_eq(machine.position.x, start_x, 0.001, "Sentry must not move")
		else:
			assert_gt(machine.position.x, start_x, b_id + " should move forward with velocity")
			
		# Test primary ability trigger
		assert_false(machine.primary_ability.is_empty(), b_id + " must have primary ability")
		machine.current_intent.primary = true
		machine.step_abilities(1)
		machine.current_intent.primary = false
		
		# Verify Heat was added or cooldown set
		var cd: int = machine.state.get_cooldown("primary")
		assert_gt(cd, 0, b_id + " primary ability should set cooldown")
		
		# Reset state for next iteration
		machine.state.current_heat = 0.0
		machine.state.cooldowns.clear()
		machine.position = Vector2(50, 50)

func test_f8_body_cycling() -> void:
	# Test that World cycle_player_body iterates sequentially through all 10 bodies
	assert_not_null(world.player_machine)
	world.player_machine.body_id = "cursor"
	
	var expected_sequence: Array[String] = [
		"janitor", "loader", "sentry", "drone",
		"welder", "diver", "crawler", "courier", "medic", "cursor"
	]
	
	for expected_id: String in expected_sequence:
		world.cycle_player_body()
		assert_eq(world.player_machine.body_id, expected_id, "F8 should cycle to " + expected_id)

func test_cursor_initial_spawn_hp() -> void:
	assert_not_null(world.player_machine)
	assert_eq(world.player_machine.body_id, "cursor", "Default spawned player is cursor")
	assert_eq(world.player_machine.state.max_integrity, 2, "Cursor max integrity must be 2")
	assert_eq(world.player_machine.state.current_integrity, 2, "Cursor current integrity must be 2")

func test_diver_land_vs_coolant_speed() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var diver: Machine = machine_scene.instantiate() as Machine
	diver.body_id = "diver"
	diver.base_speed_tiles = 3.6
	diver.mediums = ["ground", "liquid"]
	diver.current_room = world.active_room
	diver.position = Vector2(50, 50)
	world.entities_container.add_child(diver)
	world.machines.append(diver)

	# 1. On land: effective speed is 2.4 tiles/s
	diver.current_intent.move = Vector2.RIGHT
	var land_start_x: float = diver.position.x
	diver.step_movement(1.0 / 60.0)
	var land_dist: float = diver.position.x - land_start_x
	# 2.4 * 16 / 60 = 0.64 px
	assert_almost_eq(land_dist, 0.64, 0.05, "Diver on land moves at 2.4 tiles/s")

	# 2. In coolant (~ tile): effective speed is 3.6 tiles/s
	world.active_room.set_tile_at(Vector2i(5, 5), "~", false)
	diver.position = Grid.tile_to_pixel_center(Vector2i(5, 5))
	var water_start_x: float = diver.position.x
	diver.step_movement(1.0 / 60.0)
	var water_dist: float = diver.position.x - water_start_x
	# 3.6 * 16 / 60 = 0.96 px
	assert_almost_eq(water_dist, 0.96, 0.05, "Diver in coolant moves at full 3.6 tiles/s")

func test_loader_ram_impact_damage_on_machine() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var loader: Machine = machine_scene.instantiate() as Machine
	loader.body_id = "loader"
	loader.weight = 3
	loader.position = Vector2(100, 100)
	loader.facing = Vector2.RIGHT
	loader.current_room = world.active_room
	world.entities_container.add_child(loader)
	world.machines.append(loader)

	var target: Machine = machine_scene.instantiate() as Machine
	target.body_id = "janitor"
	target.weight = 1
	target.position = Vector2(116, 100) # In front of loader
	target.current_room = world.active_room
	world.entities_container.add_child(target)
	world.machines.append(target)

	var start_hp: int = target.state.current_integrity
	MovementAbilities.start_charge_dash(loader, {
		"params": { "speed": 11.0, "distance": 5.0, "damage": 3, "knockback": 2.0 }
	}, Vector2.RIGHT)

	assert_true(loader.is_dashing)
	# Step loader movement across ticks until collision with target
	for i: int in range(10):
		loader.step_movement(1.0 / 60.0)
		if target.state.current_integrity < start_hp:
			break

	assert_eq(target.state.current_integrity, start_hp - 3, "Loader ram should deal 3 impact damage to machine")
	assert_gt(target.knockback_velocity.x, 0.0, "Loader ram should apply knockback to hit machine")

func test_body_range_entities_spawned() -> void:
	# Check debug_05 spawned entities (crates + dormant machines)
	assert_gt(world.crates.size(), 0, "debug_05 should have spawned crates")
	assert_gt(world.machines.size(), 1, "debug_05 should have spawned dormant machines in addition to player")
