extends GutTest

func test_scenario_a_tutorial_hijack_with_paused_ttl() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_07")

	assert_not_null(world.player_machine)
	assert_eq(world.player_machine.body_id, "cursor")
	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR)

	# 1. Verify TTL is paused while no hijack has occurred
	var initial_ttl: int = world.hijack_fsm.ttl_ticks
	for _i: int in range(60):
		world._physics_process(1.0 / 60.0)
	assert_eq(world.hijack_fsm.ttl_ticks, initial_ttl, "TTL must remain paused in tutorial room before first hijack")

	# 2. Target and hijack dormant_janitor
	var target: Machine = world._find_machine_by_id("dormant_janitor")
	assert_not_null(target)
	assert_eq(target.operational_state, "dormant")

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# Trigger hop
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TARGETING)
	assert_eq(world.hijack_fsm.selected_target_id, "dormant_janitor")

	# Confirm hop
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TRANSIT)

	# Complete transit (48px at 320px/s takes 9-10 ticks)
	for _i: int in range(15):
		world._physics_process(1.0 / 60.0)
		if world.hijack_fsm.state == HijackFSM.State.HOSTED:
			break

	assert_eq(world.hijack_fsm.state, HijackFSM.State.HOSTED, "Scenario (a): Must seize dormant machine")
	assert_eq(world.player_machine, target)
	assert_eq(target.operational_state, "player")

func test_scenario_b_weaken_and_seize_hostile_machine() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_07")

	var hostile: Machine = world._find_machine_by_id("hostile_target")
	assert_not_null(hostile)
	assert_eq(hostile.operational_state, "hostile")
	assert_false(hostile.is_open(), "Hostile machine at full integrity must not be Open")

	# Position player cursor near hostile (within 80px)
	world.player_machine.position = hostile.position - Vector2(48.0, 0.0)

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# Attempt hop while hostile is not Open
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	# Cannot target hostile because it is not Open
	assert_ne(world.hijack_fsm.selected_target_id, "hostile_target", "Cannot target hostile that is not Open")
	world.hijack_fsm.cancel_targeting()

	# Weaken hostile to <= 35% Integrity (Janitor max integrity is 6, 2 / 6 = 33.3% <= 35%)
	hostile.state.current_integrity = 2
	assert_true(hostile.is_open(), "Hostile weakened to <= 35% integrity must become Open")

	# Now attempt hop to Open hostile
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TARGETING)
	assert_eq(world.hijack_fsm.selected_target_id, "hostile_target")

	# Confirm hop
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	# Step transit
	for _i: int in range(15):
		world._physics_process(1.0 / 60.0)
		if world.hijack_fsm.state == HijackFSM.State.HOSTED:
			break

	assert_eq(world.hijack_fsm.state, HijackFSM.State.HOSTED, "Scenario (b): Must successfully seize weakened hostile")
	assert_eq(world.player_machine, hostile)
	assert_eq(hostile.operational_state, "player")

func test_scenario_c_loader_hold_plate_and_sentry_guard_door() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_07")

	var plate: Plate = world._find_entity_by_id("plate_heavy") as Plate
	var door: Door = world._find_entity_by_id("door_01") as Door
	var loader: Machine = world._find_machine_by_id("loader_dormant")
	var sentry: Machine = world._find_machine_by_id("sentry_guard")
	var intruder: Machine = world._find_machine_by_id("intruder_janitor")

	assert_not_null(plate)
	assert_not_null(door)
	assert_not_null(loader)
	assert_not_null(sentry)
	assert_not_null(intruder)
	assert_false(door.is_open, "Door must start closed")

	# 1. Park Loader on the heavy plate with HOLD routine
	loader.position = plate.position
	loader.operational_state = "parked"
	loader.parked_routine = "HOLD"
	var p_state: ParkedState = ParkedState.new("HOLD", loader.position, loader.position, Vector2.RIGHT)
	var r_ctrl: RoutineController = RoutineController.new(p_state)
	loader.controller = r_ctrl
	loader.add_child(r_ctrl)

	plate.check_weight()
	assert_true(plate.is_pressed, "Loader (weight 3) activates heavy plate")
	assert_true(door.is_open, "Linked door opens when plate is pressed")
	assert_true(loader.get_meta("is_holding_latch", false))

	# 2. Park Sentry on GUARD routine facing right past the open door
	sentry.position = Vector2(216.0, 184.0) # between door and intruder
	sentry.facing = Vector2.RIGHT
	sentry.operational_state = "parked"
	sentry.parked_routine = "GUARD"
	var sentry_pstate: ParkedState = ParkedState.new("GUARD", sentry.position, sentry.position, Vector2.RIGHT)
	var sentry_ctrl: RoutineController = RoutineController.new(sentry_pstate)
	sentry.controller = sentry_ctrl
	sentry.add_child(sentry_ctrl)

	# Intruder is within 80px and direct line of sight
	intruder.position = Vector2(264.0, 184.0)
	var initial_hp: int = intruder.state.current_integrity

	# Step world simulation for 30 ticks
	for _i: int in range(30):
		world._physics_process(1.0 / 60.0)

	assert_true(intruder.state.current_integrity < initial_hp, "Scenario (c): Parked Sentry on GUARD must shoot and damage intruder")

func test_scenario_d_welder_repeat_cutting_weld_seam() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_08")

	var welder: Machine = world._find_machine_by_id("welder_worker")
	assert_not_null(welder)

	# Weld seam tile at [12, 4]
	var seam_tile: Vector2i = Vector2i(12, 4)
	var glyph_before: String = world.active_room.grid[seam_tile.y][seam_tile.x]
	assert_eq(glyph_before, "%", "Tile at [12, 4] must be a weld seam")

	# Position welder adjacent to seam, facing RIGHT
	welder.position = Vector2(168.0, 72.0)
	welder.facing = Vector2.RIGHT
	welder.operational_state = "parked"
	welder.parked_routine = "REPEAT"
	var p_state: ParkedState = ParkedState.new("REPEAT", welder.position, welder.position, Vector2.RIGHT)
	var r_ctrl: RoutineController = RoutineController.new(p_state)
	welder.controller = r_ctrl
	welder.add_child(r_ctrl)

	# Player cursor is positioned far away elsewhere in the room
	world.player_machine.position = Vector2(380.0, 180.0)

	# Step simulation - Welder repeatedly fires torch in place
	for _i: int in range(30):
		world._physics_process(1.0 / 60.0)

	assert_true(welder.current_intent.primary, "Scenario (d): Parked Welder on REPEAT must continuously fire primary ability")
	# Torch clears the adjacent weld tile
	var glyph_after: String = world.active_room.grid[seam_tile.y][seam_tile.x]
	assert_eq(glyph_after, ".", "Weld seam must be cut away into open floor by Welder torch")

func test_scenario_e_firewall_blocks_hop_until_disabled_via_node() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_08")

	var inode: InfraNode = world._find_entity_by_id("node_sec") as InfraNode
	var fw: Firewall = world._find_entity_by_id("firewall_sec") as Firewall
	var vault_courier: Machine = world._find_machine_by_id("vault_courier")

	assert_not_null(inode)
	assert_not_null(fw)
	assert_not_null(vault_courier)
	assert_true(fw.is_active, "Firewall starts active")

	# 1. Direct hop across corridor is blocked by active Firewall
	world.player_machine.position = Vector2(216.0, 168.0)
	vault_courier.position = Vector2(280.0, 168.0)
	fw.position = Vector2(248.0, 168.0)

	world.hijack_fsm.spark_pos = world.player_machine.position
	world.hijack_fsm.transit_target_pos = vault_courier.position
	world.hijack_fsm.transit_target_id = "vault_courier"
	world.hijack_fsm._set_state(HijackFSM.State.TRANSIT)

	for _i: int in range(15):
		world._physics_process(1.0 / 60.0)
		if world.hijack_fsm.state == HijackFSM.State.CURSOR:
			break

	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR, "Firewall blocks transit and aborts hop to CURSOR")

	# 2. Hop into maintenance node to disable Firewall
	world.player_machine.position = inode.position - Vector2(32.0, 0.0)
	world.player_machine.facing = Vector2.RIGHT
	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# Enter targeting and select node
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.selected_target_id, "node_sec")

	# Confirm hop into node
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	# Step transit into node
	for _i: int in range(12):
		world._physics_process(1.0 / 60.0)
		if world.hijack_fsm.state == HijackFSM.State.NODE_PILOT:
			break

	assert_eq(world.hijack_fsm.state, HijackFSM.State.NODE_PILOT)
	assert_true(inode.is_piloted)
	assert_false(fw.is_active, "Piloting maintenance node disables linked firewall")

	# 3. Eject from node
	script_ctrl.default_intent.eject = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.eject = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR)

	# 4. Now hop across the disabled firewall cleanly into vault_courier
	world.player_machine.position = Vector2(216.0, 168.0)
	world.player_machine.facing = Vector2.RIGHT
	world.player_machine.controller = script_ctrl
	script_ctrl.default_intent.aim = Vector2.RIGHT

	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TARGETING)
	assert_eq(world.hijack_fsm.selected_target_id, "vault_courier")

	# Confirm hop
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	for _i: int in range(25):
		world._physics_process(1.0 / 60.0)
		if world.hijack_fsm.state == HijackFSM.State.HOSTED:
			break

	assert_eq(world.hijack_fsm.state, HijackFSM.State.HOSTED, "Scenario (e): Successful hop into vault machine with firewall down")
	assert_eq(world.player_machine, vault_courier)
