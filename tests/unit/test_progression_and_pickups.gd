class_name TestProgressionAndPickups
extends GutTest

func after_each() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("reset"):
		game.call("reset")

func test_progression_pickups_stats_and_host_updates() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var m: Machine = machine_scene.instantiate() as Machine
	add_child_autofree(m)
	m.apply_body_data({
		"id": "janitor",
		"size": "S",
		"weight": 1,
		"speed": 3.0,
		"integrity": 5,
		"heat_max": 100,
		"primary": "sweep",
		"secondary": "dash",
		"passives": [],
		"medium": ["ground"]
	})
	m.operational_state = "player"

	# 1. Integrity Chip
	var p_int: ProgressionPickup = ProgressionPickup.new()
	add_child_autofree(p_int)
	p_int.entity_id = "chip_01"
	p_int.pickup_kind = "integrity_chip"
	p_int.amount = 1
	p_int.collect(m)

	if game != null:
		assert_eq(int(game.upgrades["integrity_chip"]), 1, "Integrity upgrade recorded")
	assert_eq(m.state.max_integrity, 6, "Host max integrity boosted")
	assert_eq(m.state.current_integrity, 6, "Host current integrity healed")

	# 2. Heat Sink
	var p_heat: ProgressionPickup = ProgressionPickup.new()
	add_child_autofree(p_heat)
	p_heat.entity_id = "heatsink_01"
	p_heat.pickup_kind = "heat_sink"
	p_heat.amount = 1
	p_heat.collect(m)

	if game != null:
		assert_eq(int(game.upgrades["heat_sink"]), 1, "Heat sink upgrade recorded")
	assert_eq(m.state.max_heat, 110.0, "Host heat max boosted")

	# 3. Garage Slot
	var p_slot: ProgressionPickup = ProgressionPickup.new()
	add_child_autofree(p_slot)
	p_slot.entity_id = "slot_01"
	p_slot.pickup_kind = "garage_slot"
	p_slot.amount = 1
	p_slot.collect(m)

	if game != null:
		assert_eq(int(game.upgrades["garage_slot"]), 1)
		assert_eq(int(game.garage_slots_cap), 4, "Garage slots cap increased")

	# 4. Bus Pass
	var p_bus: ProgressionPickup = ProgressionPickup.new()
	add_child_autofree(p_bus)
	p_bus.entity_id = "bus_01"
	p_bus.pickup_kind = "bus_pass"
	p_bus.collect(m)

	if game != null:
		assert_true(bool(game.has_bus_pass), "Bus pass acquired")

func test_log_pickup_discovery() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")

	var log_p: LogPickup = LogPickup.new()
	add_child_autofree(log_p)
	log_p.entity_id = "log_terminal_01"
	log_p.log_id = "log_lore_security"
	log_p.log_title = "Incident Report 404"
	log_p.log_text = "Corrupted core memory in Sector 7."

	log_p.collect(null)

	if game != null:
		assert_true(game.logs.has("log_lore_security"), "Log added to Game.logs")

func test_room_discovery_and_fast_travel() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return
	game.call("reset")

	# Room discovery
	game.discover_room("debug_01")
	assert_true(game.discovered_rooms.has("debug_01"), "debug_01 discovered")
	# Re-discovering doesn't duplicate
	game.discover_room("debug_01")
	assert_eq(game.discovered_rooms.size(), 1)

	# Fast travel test
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)

	game.visited_docks.append("debug_05")
	# Without bus pass -> false
	assert_false(game.fast_travel_to_dock("debug_05", world), "Cannot fast travel without bus pass")

	game.has_bus_pass = true
	assert_false(game.fast_travel_to_dock("unknown_dock", world), "Cannot fast travel to unvisited dock")
	assert_true(game.fast_travel_to_dock("debug_05", world), "Fast travels to visited dock with bus pass")
	assert_eq(world.current_room_id, "debug_05", "World loaded dock room")
