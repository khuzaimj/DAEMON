extends GutTest

func test_open_rules_hostile_weakening_and_overload() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	var origin: Vector2 = Vector2(100.0, 100.0)

	var target_scene: PackedScene = load("res://scenes/machine.tscn")
	var hostile: Machine = autofree(target_scene.instantiate()) as Machine
	hostile.entity_id = "rogue_janitor_1"
	hostile.body_id = "janitor"
	hostile.operational_state = "hostile"
	hostile.position = Vector2(132.0, 100.0)
	hostile.state.max_integrity = 10
	hostile.state.current_integrity = 10

	# 1. Full health hostile is NOT open
	assert_false(hostile.is_open())
	var cand_dict: Dictionary = {
		"id": hostile.entity_id,
		"kind": "machine",
		"model": hostile.body_id,
		"state": hostile.operational_state,
		"is_open": hostile.is_open(),
		"pos": hostile.position,
		"clearance": hostile.clearance_level,
		"is_immune_unit": hostile.is_immune_unit,
		"is_boss_body": hostile.is_boss_body,
		"has_los": true
	}
	assert_false(HijackFSM.is_candidate_valid(cand_dict, origin, fsm.get_link_range_px(), fsm.player_clearance))

	# 2. Weaken hostile to 35% HP (3/10) -> becomes open
	hostile.state.current_integrity = 3
	assert_true(hostile.is_open(), "Integrity <= 35% must make hostile Open")
	cand_dict["is_open"] = hostile.is_open()
	assert_true(HijackFSM.is_candidate_valid(cand_dict, origin, fsm.get_link_range_px(), fsm.player_clearance))

	# 3. Full health hostile with overload status is Open
	hostile.state.current_integrity = 10
	hostile.state.apply_status("overload", 60)
	assert_true(hostile.is_open(), "Overloaded hostile must be Open")
	cand_dict["is_open"] = hostile.is_open()
	assert_true(HijackFSM.is_candidate_valid(cand_dict, origin, fsm.get_link_range_px(), fsm.player_clearance))

	# 4. Immune units or boss bodies can never be targeted
	cand_dict["is_immune_unit"] = true
	assert_false(HijackFSM.is_candidate_valid(cand_dict, origin, fsm.get_link_range_px(), fsm.player_clearance))

func test_link_range_upgrade_scaling() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	assert_almost_eq(fsm.get_link_range_tiles(), 5.0, 0.001)
	assert_almost_eq(fsm.get_link_range_px(), 80.0, 0.001)

	var origin: Vector2 = Vector2(100.0, 100.0)
	var candidate: Dictionary = {
		"id": "target_m",
		"kind": "machine",
		"model": "janitor",
		"state": "dormant",
		"is_open": true,
		"pos": Vector2(190.0, 100.0), # 90px away
		"clearance": 0,
		"is_immune_unit": false,
		"is_boss_body": false,
		"has_los": true
	}

	# 90px is beyond base 80px range
	assert_false(HijackFSM.is_candidate_valid(candidate, origin, fsm.get_link_range_px(), fsm.player_clearance))

	# Upgrade link range by 1 (+2 tiles = 7 tiles = 112px)
	fsm.link_range_upgrades = 1
	assert_almost_eq(fsm.get_link_range_tiles(), 7.0, 0.001)
	assert_almost_eq(fsm.get_link_range_px(), 112.0, 0.001)
	assert_true(HijackFSM.is_candidate_valid(candidate, origin, fsm.get_link_range_px(), fsm.player_clearance))

	# Cap at 11 tiles (176px)
	fsm.link_range_upgrades = 5
	assert_almost_eq(fsm.get_link_range_tiles(), 11.0, 0.001)
	assert_almost_eq(fsm.get_link_range_px(), 176.0, 0.001)

func test_dock_checkpoint_save_and_fabrication() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")
		game.set("scrap", 50)

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var dock: Dock = autofree(Dock.new()) as Dock
	dock.entity_id = "test_dock_alpha"
	dock.position = Vector2(120.0, 120.0)
	world.entities_container.add_child(dock)

	# Damage player and add heat
	world.player_machine.take_damage(1, "kinetic", true)
	world.player_machine.add_heat(50.0)
	assert_lt(world.player_machine.state.current_integrity, world.player_machine.state.max_integrity)
	assert_gt(world.player_machine.state.current_heat, 0.0)

	# Player enters dock
	dock.activate_dock(world.player_machine)

	# Checkpoint and heal checks
	if game != null:
		assert_eq(str(game.get("last_dock_room_id")), "debug_05")
		assert_eq(world.player_machine.state.current_integrity, world.player_machine.state.max_integrity)
		assert_almost_eq(world.player_machine.state.current_heat, 0.0, 0.001)

	# Fabrication test
	var registered: Array[String] = ["cursor", "janitor", "loader"]
	assert_true(dock.can_fabricate("janitor", registered, 50))
	assert_false(dock.can_fabricate("welder", registered, 50), "Unregistered body cannot be fabricated")
	assert_false(dock.can_fabricate("loader", registered, 5), "Insufficient scrap cannot fabricate")

	var fab_m: Machine = dock.fabricate("janitor", world)
	assert_not_null(fab_m)
	assert_eq(fab_m.body_id, "janitor")
	assert_eq(fab_m.operational_state, "dormant")
	if game != null:
		assert_lt(int(game.get("scrap")), 50, "Scrap must be deducted on fabrication")

func test_dock_activation_respawns_room_enemies() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_09")

	var dock: Dock = autofree(Dock.new()) as Dock
	dock.entity_id = "test_arena_dock"
	dock.position = Vector2(40.0, 40.0)
	world.entities_container.add_child(dock)

	# Find enemy in debug_09
	var target_enemy: Machine = null
	for m: Machine in world.machines:
		if m.entity_id == "enemy_janitor_heavy":
			target_enemy = m
			break
	assert_not_null(target_enemy, "Enemy enemy_janitor_heavy should exist in debug_09")

	# Destroy the enemy (step through hit-stop ticks into combat cleanup)
	target_enemy.take_damage(999, "kinetic", true)
	for i: int in range(5):
		world._physics_process(1.0 / 60.0)
	assert_false(world.machines.has(target_enemy), "Defeated enemy should be removed from world machines")
	assert_true(world.defeated_enemies_in_room.has("enemy_janitor_heavy"), "Defeated enemy recorded")

	# Activate dock
	dock.activate_dock(world.player_machine)

	# Enemy should be respawned in world.machines
	var respawned: Machine = null
	for m: Machine in world.machines:
		if m.entity_id == "enemy_janitor_heavy":
			respawned = m
			break
	assert_not_null(respawned, "Enemy should be respawned after dock activation")
	assert_eq(respawned.operational_state, "hostile")
	assert_false(world.defeated_enemies_in_room.has("enemy_janitor_heavy"), "Defeated list should be cleared")
