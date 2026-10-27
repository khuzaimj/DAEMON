extends GutTest

func test_parked_host_persists_across_room_transitions() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	# Spawn and park a loader in debug_05
	var loader_scene: PackedScene = load("res://scenes/machine.tscn")
	var loader: Machine = loader_scene.instantiate() as Machine
	loader.entity_id = "persisted_loader_1"
	loader.body_id = "loader"
	loader.position = Vector2(120.0, 120.0)
	loader.facing = Vector2.RIGHT
	loader.operational_state = "parked"
	loader.parked_routine = "guard"
	world.entities_container.add_child(loader)
	world.register_machine(loader)

	# Transition/load to debug_06
	world.load_room("debug_06")

	# Check persistent storage
	if game != null:
		var p_hosts: Dictionary = game.get("persistent_parked_hosts")
		assert_true(p_hosts.has("debug_05"), "debug_05 must have persistent parked hosts")
		var arr: Array = p_hosts["debug_05"]
		assert_eq(arr.size(), 1)
		assert_eq(str(arr[0]["id"]), "persisted_loader_1")
		assert_eq(str(arr[0]["routine"]), "guard")

	# Return to debug_05
	world.load_room("debug_05")

	var restored: Machine = world._find_machine_by_id("persisted_loader_1")
	assert_not_null(restored, "Loader must be restored when returning to debug_05")
	assert_eq(restored.body_id, "loader")
	assert_eq(restored.operational_state, "parked")
	assert_eq(restored.parked_routine, "guard")
	assert_almost_eq(restored.position.x, 120.0, 1.0)
	assert_almost_eq(restored.position.y, 120.0, 1.0)
	assert_true(restored.controller is RoutineController)

func test_garage_slots_limit_recycles_oldest_host() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")
		game.set("scrap", 0)
		game.set("garage_slots_cap", 3)

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var recycled_events: Array[String] = []
	var events: Node = get_node_or_null("/root/Events")
	if events != null:
		events.connect("host_recycled", func(hid: String, _refund: int) -> void:
			recycled_events.append(hid)
		)

	# Populate persistent hosts in other rooms (1, 2, 3, 4)
	if game != null:
		var p_hosts: Dictionary = game.get("persistent_parked_hosts")
		p_hosts["debug_01"] = [{ "id": "host_oldest", "model": "janitor", "pos": [50, 50], "parked_tick": 10, "is_holding_latch": false }]
		p_hosts["debug_02"] = [{ "id": "host_mid1", "model": "loader", "pos": [50, 50], "parked_tick": 20, "is_holding_latch": false }]
		p_hosts["debug_03"] = [{ "id": "host_mid2", "model": "sentry", "pos": [50, 50], "parked_tick": 30, "is_holding_latch": false }]
		p_hosts["debug_04"] = [{ "id": "host_newest", "model": "welder", "pos": [50, 50], "parked_tick": 40, "is_holding_latch": false }]

	# Enforce cap (cap is 3, currently 4 outside hosts)
	world._enforce_garage_slots_cap()

	if game != null:
		var p_hosts: Dictionary = game.get("persistent_parked_hosts")
		assert_false(p_hosts.has("debug_01"), "Oldest host in debug_01 must be recycled")
		assert_true(p_hosts.has("debug_02"))
		assert_true(p_hosts.has("debug_03"))
		assert_true(p_hosts.has("debug_04"))
		assert_eq(recycled_events, ["host_oldest"])
		assert_eq(int(game.get("scrap")), 10, "Scrap refund must be awarded")

func test_latched_host_protected_from_recycling() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")
		game.set("scrap", 0)
		game.set("garage_slots_cap", 3)

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	# Populate persistent hosts with oldest being latched
	if game != null:
		var p_hosts: Dictionary = game.get("persistent_parked_hosts")
		p_hosts["debug_01"] = [{ "id": "latched_loader", "model": "loader", "pos": [50, 50], "parked_tick": 5, "is_holding_latch": true }]
		p_hosts["debug_02"] = [{ "id": "host_second_oldest", "model": "janitor", "pos": [50, 50], "parked_tick": 10, "is_holding_latch": false }]
		p_hosts["debug_03"] = [{ "id": "host_3", "model": "sentry", "pos": [50, 50], "parked_tick": 20, "is_holding_latch": false }]
		p_hosts["debug_04"] = [{ "id": "host_4", "model": "welder", "pos": [50, 50], "parked_tick": 30, "is_holding_latch": false }]

	world._enforce_garage_slots_cap()

	if game != null:
		var p_hosts: Dictionary = game.get("persistent_parked_hosts")
		assert_true(p_hosts.has("debug_01"), "Latched host must NOT be recycled")
		assert_false(p_hosts.has("debug_02"), "Second oldest non-latched host must be recycled instead")
