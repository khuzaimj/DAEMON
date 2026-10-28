class_name TestClearanceAndFirewalls
extends GutTest

func after_each() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("reset"):
		game.call("reset")

func test_clearance_doors_and_hijack_fsm() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")
		game.set("clearance", 1)

	var door: Door = Door.new()
	add_child_autofree(door)
	door.entity_id = "door_l2"
	door.clearance_level = 2
	door.set_energized(true, 1)
	assert_false(door.is_open, "Clearance L2 door stays locked when Game.clearance is 1")

	if game != null:
		game.set("clearance", 2)
	door.set_energized(true, 2)
	assert_true(door.is_open, "Clearance L2 door opens when Game.clearance is 2")

	# HijackFSM candidate filtering by clearance
	var fsm: HijackFSM = HijackFSM.new()
	fsm.player_clearance = 1
	var cand_l2: Dictionary = {
		"id": "sentry_heavy",
		"kind": "machine",
		"state": "dormant",
		"is_open": true,
		"pos": Vector2(100, 100),
		"clearance": 2,
		"has_los": true
	}
	assert_false(HijackFSM.is_candidate_valid(cand_l2, Vector2(100, 100), 200.0, fsm.player_clearance), "L2 candidate invalid with L1 player")
	fsm.player_clearance = 2
	assert_true(HijackFSM.is_candidate_valid(cand_l2, Vector2(100, 100), 200.0, fsm.player_clearance), "L2 candidate valid with L2 player")

func test_three_shards_auto_grants_clearance_l2() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return
	game.call("reset")
	assert_eq(int(game.get("clearance")), 0)

	# Test normalization of single "shard" pickups
	game.call("add_upgrade", "shard", 2)
	assert_eq(int(game.get("clearance")), 0, "2 shards do not grant L2")
	assert_eq(int(game.upgrades["shards"]), 2, "'shard' normalized to 'shards'")

	game.call("add_upgrade", "shard", 1)
	assert_true(int(game.get("clearance")) >= 2, "3 shards automatically grant Clearance L2")
	assert_eq(int(game.upgrades["shards"]), 3, "'shards' count is 3")

func test_unique_enemy_death_persistence() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	world.load_room("debug_09")

	# In debug_09, we have enemies. Let's create two enemies of the same template type
	var m1: Machine = (load("res://scenes/machine.tscn") as PackedScene).instantiate() as Machine
	add_child_autofree(m1)
	m1.entity_id = "test_janitor_inst_1"
	m1.enemy_id = "rogue_janitor"
	m1.operational_state = "hostile"
	world.machines.append(m1)

	var m2: Machine = (load("res://scenes/machine.tscn") as PackedScene).instantiate() as Machine
	add_child_autofree(m2)
	m2.entity_id = "test_janitor_inst_2"
	m2.enemy_id = "rogue_janitor"
	m2.operational_state = "hostile"
	world.machines.append(m2)

	# Defeat m1
	var combat_sys: CombatSystem = CombatSystem.new()
	combat_sys._process_enemy_death(world, m1)

	# Check defeated list
	assert_true(world.defeated_enemies_in_room.has("test_janitor_inst_1"), "Killed instance 1 is recorded")
	assert_false(world.defeated_enemies_in_room.has("test_janitor_inst_2"), "Instance 2 must not be recorded")
	assert_false(world.defeated_enemies_in_room.has("rogue_janitor"), "Shared template ID must NOT be recorded")
