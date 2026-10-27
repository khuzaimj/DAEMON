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
