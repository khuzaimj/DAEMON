class_name TestLogicLab
extends GutTest

func after_each() -> void:
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys != null:
		var p_main: String = "%s/slot1.json" % SaveSystem.SAVES_DIR
		var p_bak: String = p_main + ".bak"
		if FileAccess.file_exists(p_main):
			DirAccess.remove_absolute(p_main)
		if FileAccess.file_exists(p_bak):
			DirAccess.remove_absolute(p_bak)

	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("reset"):
		game.call("reset")

func test_logic_lab_puzzle_and_persistence_scenario() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)

	# 1. Load debug_11 (Logic Lab 1)
	world.load_room("debug_11")
	assert_eq(world.current_room_id, "debug_11", "debug_11 loaded")
	if game != null:
		assert_true(game.discovered_rooms.has("debug_11"), "debug_11 discovered")

	# 2. Check entities registered in LogicSystem
	assert_not_null(world.logic_system, "LogicSystem exists")
	var bridge_node: Node = world.logic_system.get_entity("bridge_1")
	assert_not_null(bridge_node, "Bridge registered in logic system")

	# 3. Toggle switch_1 to activate latch_1 and extend bridge_1
	var switch_node: Switch = world.logic_system.get_entity("switch_1") as Switch
	assert_not_null(switch_node, "Switch registered")
	switch_node.trigger()

	# Step logic to propagate signals
	world.logic_system.step(world, 1)
	assert_true(world.logic_system.is_active("latch_1"), "Latch 1 activated by switch")
	assert_true(world.logic_system.is_active("bridge_1"), "Bridge 1 activated by latch")
	var br: Bridge = bridge_node as Bridge
	assert_true(br.is_active, "Bridge extended over pit")

	# 4. Transition to debug_12 (Progression Lab 2)
	world.load_room("debug_12")
	assert_eq(world.current_room_id, "debug_12", "debug_12 loaded")
	if game != null:
		assert_true(game.discovered_rooms.has("debug_12"), "debug_12 discovered")

	# 5. Collect progression pickups in debug_12
	var pickups: Array = world.get_tree().get_nodes_in_group("progression_pickups")
	assert_gt(pickups.size(), 0, "Pickups spawned in debug_12")
	for p_node: Node in pickups:
		if p_node is ProgressionPickup and is_instance_valid(p_node):
			(p_node as ProgressionPickup).collect(world.player_machine)

	if game != null:
		assert_gt(int(game.upgrades["integrity_chip"]), 0, "Integrity upgrade collected")
		assert_gt(int(game.upgrades["link_range"]), 0, "Link range upgrade collected")
		assert_true(bool(game.has_bus_pass), "Bus pass collected")

	# Collect log pickup
	var logs: Array = world.get_tree().get_nodes_in_group("logs")
	assert_gt(logs.size(), 0, "Log terminal spawned")
	for l_node: Node in logs:
		if l_node is LogPickup and is_instance_valid(l_node):
			(l_node as LogPickup).collect(world.player_machine)

	if game != null:
		assert_true(game.logs.has("log_debug_overview"), "Log collected into Game.logs")

	# 6. Save slot 1
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	assert_not_null(save_sys, "SaveSystem autoload registered")
	var saved: bool = save_sys.call("save_slot", 1)
	assert_true(saved, "Slot 1 saved successfully")

	# 7. Modify Game state (reset) and restore via load_slot
	if game != null:
		game.call("reset")
		assert_eq(int(game.upgrades["integrity_chip"]), 0, "Game state cleared")

	var loaded_data: Dictionary = save_sys.call("load_slot", 1)
	assert_false(loaded_data.is_empty(), "Loaded save data not empty")
	save_sys.call("apply_save_to_game", loaded_data, world)

	if game != null:
		assert_gt(int(game.upgrades["integrity_chip"]), 0, "Integrity upgrade restored")
		assert_true(bool(game.has_bus_pass), "Bus pass restored")
		assert_true(game.logs.has("log_debug_overview"), "Logs restored")
		assert_true(game.discovered_rooms.has("debug_11"), "Discovered rooms restored")
		assert_true(game.discovered_rooms.has("debug_12"), "Discovered rooms restored")
