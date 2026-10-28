class_name TestImmuneUnitsAndBitrot
extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autofree(world)
	world.load_room("debug_07")

func test_glitch_mite_heat_and_self_destruct() -> void:
	var player: Machine = world.player_machine
	assert_not_null(player)
	player.position = Vector2(100, 100)
	var initial_heat: float = player.state.current_heat

	var mite: ImmuneUnit = ImmuneUnit.new("glitch_mite")
	mite.position = Vector2(108, 100) # within 8 px contact
	world.entities_container.add_child(mite)
	world.register_machine(mite)

	assert_true(mite.is_immune_unit, "Glitch mite must be immune unit")

	# Step world
	world._physics_process(1.0 / 60.0)

	assert_true(player.state.current_heat > initial_heat, "Glitch mite contact must add Heat")
	assert_eq(mite.state.current_integrity, 0, "Glitch mite must self-destruct on contact")

	# Step combat to resolve death & scrap
	world._step_combat(1.0 / 60.0)
	var pickups: Array = []
	for child: Node in world.entities_container.get_children():
		if child is ScrapPickup:
			pickups.append(child)
	assert_gt(pickups.size(), 0, "Dead glitch mite should drop scrap")

func test_antivirus_sentinel_targets_exposed_cursor_and_fires_seeking_bolt() -> void:
	var player: Machine = world.player_machine
	player.position = Vector2(100, 100)
	# Set player to exposed cursor
	player.body_id = "cursor"
	world.hijack_fsm.state = HijackFSM.State.CURSOR

	var sentinel: ImmuneUnit = ImmuneUnit.new("antivirus_sentinel")
	sentinel.position = Vector2(160, 100)
	world.entities_container.add_child(sentinel)
	world.register_machine(sentinel)

	assert_true(sentinel.is_immune_unit)

	# Step 65 ticks to trigger firing
	for i: int in range(65):
		world._physics_process(1.0 / 60.0)

	assert_gt(world.projectiles.size(), 0, "Sentinel should fire bolt at exposed cursor")
	var proj: Projectile = world.projectiles[0]
	assert_not_null(proj.seeking_target, "Bolt should seek target")
	assert_gt(proj.seek_turn_rate, 0.0, "Bolt should have non-zero seek turn rate")

	# Move cursor down, step projectile to verify steering
	player.position = Vector2(100, 140)
	var initial_vel: Vector2 = proj.velocity
	proj.step(0.1)
	assert_ne(proj.velocity, initial_vel, "Seeking projectile should curve toward moved cursor")

func test_quarantine_pod_traps_and_releases_parked_host() -> void:
	# Spawn a parked machine
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var parked_m: Machine = machine_scene.instantiate() as Machine
	parked_m.entity_id = "parked_janitor"
	parked_m.body_id = "janitor"
	parked_m.operational_state = "parked"
	parked_m.position = Vector2(120, 100)
	world.entities_container.add_child(parked_m)
	world.register_machine(parked_m)

	# Spawn quarantine pod nearby
	var pod: ImmuneUnit = ImmuneUnit.new("quarantine_pod")
	pod.position = Vector2(140, 100)
	world.entities_container.add_child(pod)
	world.register_machine(pod)

	# Step 20 ticks to let pod quarantine the host
	for i: int in range(20):
		world._physics_process(1.0 / 60.0)

	assert_true(bool(parked_m.get_meta("quarantined", false)), "Parked host should be quarantined")

	# Check hijack candidates: candidate is trapped and invalid
	var candidates: Array[Dictionary] = world._get_hijack_candidates(Vector2(100, 100))
	var cand_trapped: bool = false
	for c: Dictionary in candidates:
		if c.get("id") == "parked_janitor":
			cand_trapped = bool(c.get("is_trapped", false))
			assert_false(HijackFSM.is_candidate_valid(c, Vector2(100, 100), 200.0, 0), "Trapped candidate cannot be hijacked")
	assert_true(cand_trapped, "Candidate should report is_trapped")

	# Destroy pod
	pod.take_damage(6, "kinetic")
	world._step_combat(1.0 / 60.0)

	assert_false(bool(parked_m.get_meta("quarantined", false)), "Host should be freed when pod destroyed")

func test_garbage_collector_deletes_parked_host_on_contact() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var parked_m: Machine = machine_scene.instantiate() as Machine
	parked_m.entity_id = "target_host"
	parked_m.body_id = "loader"
	parked_m.operational_state = "parked"
	parked_m.position = Vector2(108, 100)
	world.entities_container.add_child(parked_m)
	world.register_machine(parked_m)

	var gc: ImmuneUnit = ImmuneUnit.new("garbage_collector")
	gc.position = Vector2(100, 100)
	world.entities_container.add_child(gc)
	world.register_machine(gc)

	var recycled_events: Array[String] = []
	var events_node: Node = world.get_node_or_null("/root/Events")
	if events_node != null:
		events_node.connect("host_recycled", func(_id: String, _refund: int) -> void:
			recycled_events.append(_id)
		)

	# Step 1 tick for contact resolution
	world._physics_process(1.0 / 60.0)

	assert_false(world.machines.has(parked_m), "Garbage collector must remove parked host from machines")
	assert_gt(recycled_events.size(), 0, "host_recycled event should be emitted")

func test_firewall_node_blocks_and_opens_via_maintenance_node() -> void:
	var fwn: FirewallNode = FirewallNode.new()
	fwn.entity_id = "fw_node_01"
	fwn.position = Vector2(120, 100)
	fwn.barrier_length_px = 64.0
	fwn.barrier_direction = Vector2.DOWN
	world.entities_container.add_child(fwn)

	# Step physics so collision shape synchronizes in space state
	world._physics_process(1.0 / 60.0)

	# Raycast across barrier: (100, 120) to (140, 120) intersects barrier
	var hit: Variant = world.check_transit_firewall(Vector2(100, 120), Vector2(140, 120))
	assert_not_null(hit, "Active firewall node must block transit hop")

	# Trigger maintenance node toggle
	world.room_links = [{ "from": "node_maint", "to": "fw_node_01" }]
	world.trigger_links("node_maint", true)

	assert_false(fwn.is_active, "Firewall node should be deactivated")
	world._physics_process(1.0 / 60.0)

	var hit_after: Variant = world.check_transit_firewall(Vector2(100, 120), Vector2(140, 120))
	assert_null(hit_after, "Disabled firewall node must allow transit hop")

func test_bitrot_hazard_damage_spread_and_sweep_clear() -> void:
	var room: RoomRuntime = world.active_room
	assert_not_null(room)

	# Place bitrot tile at (5, 5)
	var cell: Vector2i = Vector2i(5, 5)
	room.set_tile_at(cell, "*", false)
	assert_eq(room.grid[5][5], "*", "Bitrot tile placed")

	# Place non-Janitor (Loader) on (5, 5)
	var loader_m: Machine = world.player_machine
	loader_m.body_id = "loader"
	loader_m.passives.clear()
	loader_m.position = Grid.tile_to_pixel_center(cell)
	var initial_hp: int = loader_m.state.current_integrity

	# Step 60 ticks: Loader should take 1 damage
	room.step_bitrot(world, 60)
	assert_eq(loader_m.state.current_integrity, initial_hp - 1, "Non-Janitor on bitrot takes damage")

	# Change player to Janitor: immune to bitrot
	loader_m.body_id = "janitor"
	loader_m.passives.append("bitrot_immune")
	initial_hp = loader_m.state.current_integrity
	room.step_bitrot(world, 60)
	assert_eq(loader_m.state.current_integrity, initial_hp, "Janitor on bitrot is immune")

	# Step 120 ticks: Bitrot should spread to adjacent floor tile
	var initial_bitrot_count: int = 0
	for row: String in room.grid:
		for ch: String in row:
			if ch == "*":
				initial_bitrot_count += 1

	room.step_bitrot(world, 120)
	var new_bitrot_count: int = 0
	for row: String in room.grid:
		for ch: String in row:
			if ch == "*":
				new_bitrot_count += 1
	assert_gt(new_bitrot_count, initial_bitrot_count, "Bitrot must spread on logic tick")

	# Janitor sweeps to clear bitrot
	var cleared: int = room.clear_tiles_in_arc(Grid.tile_to_pixel_center(cell), Vector2.DOWN, 180.0, 32.0, "sweep")
	assert_gt(cleared, 0, "Janitor sweep clears bitrot tiles")
	assert_eq(room.grid[5][5], ".", "Bitrot tile reverted to floor")
