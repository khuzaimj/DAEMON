extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_01")

func test_sweep_clears_grime_tiles() -> void:
	var room: RoomRuntime = world.active_room
	assert_not_null(room)
	
	# Place a grime tile at cell (5, 5)
	var grime_cell: Vector2i = Vector2i(5, 5)
	room.set_tile_at(grime_cell, ",", false)
	assert_eq(room.grid[5][5], ",")
	
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var janitor: Machine = machine_scene.instantiate() as Machine
	janitor.body_id = "janitor"
	janitor.position = Grid.tile_to_pixel_center(Vector2i(4, 5)) # Directly west of grime
	janitor.facing = Vector2.RIGHT
	janitor.current_room = room
	world.entities_container.add_child(janitor)
	world.machines.append(janitor)
	
	# Sweep east
	MeleeAbilities.start_melee_arc(janitor, {
		"params": { "arc": 90.0, "radius": 24.0, "damage": 2, "knockback": 2.0, "clears": "sweep" }
	}, Vector2.RIGHT)
	
	# Grime tile should be cleared to floor '.'
	assert_eq(room.grid[5][5], ".", "Janitor sweep should clear grime to floor '.'")

func test_ram_breaks_cracked_wall() -> void:
	var room: RoomRuntime = world.active_room
	assert_not_null(room)
	
	# Place a cracked wall at cell (6, 5)
	var cracked_cell: Vector2i = Vector2i(6, 5)
	room.set_tile_at(cracked_cell, "X", true)
	assert_eq(room.grid[5][6], "X")
	
	# Breaking by ram at tile pixel center
	var cracked_pos: Vector2 = Grid.tile_to_pixel_center(cracked_cell)
	var broken: bool = room.break_tile_at(cracked_pos, "ram")
	assert_true(broken, "break_tile_at should succeed with 'ram' on 'X' tile")
	assert_eq(room.grid[5][6], ".", "Broken cracked wall becomes floor '.'")

func test_claw_damage_and_suction_pull() -> void:
	var room: RoomRuntime = world.active_room
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	
	var crawler: Machine = machine_scene.instantiate() as Machine
	crawler.body_id = "crawler"
	crawler.position = Vector2(100, 100)
	crawler.facing = Vector2.RIGHT
	crawler.current_room = room
	world.entities_container.add_child(crawler)
	world.machines.append(crawler)
	
	var target: Machine = machine_scene.instantiate() as Machine
	target.body_id = "cursor"
	target.weight = 0
	target.position = Vector2(112, 100) # In front of crawler
	target.current_room = room
	world.entities_container.add_child(target)
	world.machines.append(target)
	
	var start_hp: int = target.state.current_integrity
	MeleeAbilities.start_claw(crawler, {
		"params": { "arc": 60.0, "radius": 18.0, "damage": 2, "knockback": 1.0 }
	}, Vector2.RIGHT)
	
	assert_lt(target.state.current_integrity, start_hp, "Claw should damage target in arc")
	assert_gt(target.knockback_velocity.x, 0.0, "Knockback impulse should be applied to target")
	var target_start_x: float = target.position.x
	target.step_movement(1.0 / 60.0)
	assert_gt(target.position.x, target_start_x, "Target position should shift from knockback after step_movement()")

	# Test suction
	var far_target: Machine = machine_scene.instantiate() as Machine
	far_target.body_id = "cursor"
	far_target.weight = 0
	far_target.position = Vector2(140, 100) # 40px away, within 64px radius
	far_target.current_room = room
	world.entities_container.add_child(far_target)
	world.machines.append(far_target)
	
	var start_dist: float = crawler.position.distance_to(far_target.position)
	MeleeAbilities.start_suction(crawler, {
		"params": { "radius": 64.0, "pull_speed": 120.0 }
	}, Vector2.ZERO)
	
	var end_dist: float = crawler.position.distance_to(far_target.position)
	assert_lt(end_dist, start_dist, "Suction should pull target closer")

	# Test faction filtering on claw
	var hostile_crawler: Machine = machine_scene.instantiate() as Machine
	hostile_crawler.faction = "hostile"
	hostile_crawler.position = Vector2(200, 200)
	hostile_crawler.facing = Vector2.RIGHT
	world.entities_container.add_child(hostile_crawler)
	world.machines.append(hostile_crawler)

	var hostile_ally: Machine = machine_scene.instantiate() as Machine
	hostile_ally.faction = "hostile"
	hostile_ally.position = Vector2(212, 200)
	world.entities_container.add_child(hostile_ally)
	world.machines.append(hostile_ally)

	var ally_hp: int = hostile_ally.state.current_integrity
	MeleeAbilities.start_claw(hostile_crawler, {
		"params": { "arc": 60.0, "radius": 18.0, "damage": 2, "knockback": 1.0 }
	}, Vector2.RIGHT)
	assert_eq(hostile_ally.state.current_integrity, ally_hp, "Hostile claw should not damage hostile ally")

func test_knockback_resist_passive() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var normal_machine: Machine = machine_scene.instantiate() as Machine
	add_child_autoqfree(normal_machine)
	normal_machine.apply_knockback(Vector2(100.0, 0.0))
	assert_almost_eq(normal_machine.knockback_velocity.x, 100.0, 0.01)

	var resist_machine: Machine = machine_scene.instantiate() as Machine
	add_child_autoqfree(resist_machine)
	resist_machine.passives = ["knockback_resist"]
	resist_machine.apply_knockback(Vector2(100.0, 0.0))
	assert_almost_eq(resist_machine.knockback_velocity.x, 25.0, 0.01, "Knockback resist reduces knockback by 75%")
