extends GutTest

func test_firewall_blocks_transit_and_drops_cursor() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var player: Machine = world.player_machine
	player.position = Vector2(80.0, 120.0)

	# Target machine on the right
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var target: Machine = machine_scene.instantiate() as Machine
	target.entity_id = "target_janitor"
	target.body_id = "janitor"
	target.position = Vector2(144.0, 120.0)
	target.operational_state = "dormant"
	world.entities_container.add_child(target)
	world.register_machine(target)

	# Firewall in between at x=112
	var fw: Firewall = Firewall.new()
	fw.entity_id = "fw_test"
	fw.position = Vector2(112.0, 120.0)
	fw.set_active(true)
	world.entities_container.add_child(fw)

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	player.controller = script_ctrl

	# Note: In line of sight, firewall blocks LOS
	# But test manual transit collision step with firewall
	world.hijack_fsm.spark_pos = Vector2(80.0, 120.0)
	world.hijack_fsm.transit_target_pos = Vector2(144.0, 120.0)
	world.hijack_fsm.transit_target_id = "target_janitor"
	world.hijack_fsm._set_state(HijackFSM.State.TRANSIT)

	# Step transit - hits firewall at x=112
	for _i: int in range(12):
		world._physics_process(1.0 / 60.0)
		if world.hijack_fsm.state == HijackFSM.State.CURSOR:
			break
	# After transit blocked, state becomes CURSOR and spark drops
	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR, "Firewall must abort transit and drop daemon to CURSOR")

func test_node_piloting_and_linked_firewall_toggle() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	# Add Node and Firewall with link
	var inode: InfraNode = InfraNode.new()
	inode.entity_id = "node_main"
	inode.position = Vector2(80.0, 120.0)
	world.entities_container.add_child(inode)

	var fw: Firewall = Firewall.new()
	fw.entity_id = "fw_gate"
	fw.position = Vector2(120.0, 120.0)
	fw.set_active(true)
	world.entities_container.add_child(fw)

	world.room_links = [
		{ "from": "node_main", "to": "fw_gate" }
	]

	# Position cursor near node and hop in
	world.player_machine.position = Vector2(60.0, 120.0)
	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# Enter targeting
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TARGETING)
	assert_eq(world.hijack_fsm.selected_target_id, "node_main")

	# Confirm hop into node
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	# Step transit
	for _i: int in range(10):
		world._physics_process(1.0 / 60.0)

	assert_eq(world.hijack_fsm.state, HijackFSM.State.NODE_PILOT, "Must enter NODE_PILOT upon arriving at node")
	assert_true(inode.is_piloted)
	assert_false(fw.is_active, "Seizing node must operate linked firewall and disable it")

	# Voluntary eject from node
	script_ctrl.default_intent.eject = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.eject = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR, "Ejecting from node must return to CURSOR")
	assert_false(inode.is_piloted)

func test_plate_and_door_link() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var plate: Plate = Plate.new()
	plate.entity_id = "plate_heavy"
	plate.position = Vector2(80.0, 120.0)
	plate.weight_threshold = 3 # Needs Loader (wt 3)
	world.entities_container.add_child(plate)

	var door: Door = Door.new()
	door.entity_id = "door_vault"
	door.position = Vector2(120.0, 120.0)
	door.set_open(false)
	world.entities_container.add_child(door)

	world.room_links = [
		{ "from": "plate_heavy", "to": "door_vault" }
	]

	assert_false(door.is_open)

	# 1. Light machine (weight 1) steps on plate -> not enough weight
	var janitor_scene: PackedScene = load("res://scenes/machine.tscn")
	var janitor: Machine = janitor_scene.instantiate() as Machine
	janitor.body_id = "janitor"
	janitor.weight = 1
	janitor.position = Vector2(80.0, 120.0)
	world.entities_container.add_child(janitor)

	plate.check_weight()
	assert_false(plate.is_pressed)
	assert_false(door.is_open)

	# 2. Loader (weight 3) steps on plate -> activates plate and opens door
	janitor.position = Vector2(200.0, 200.0)
	var loader_scene: PackedScene = load("res://scenes/machine.tscn")
	var loader: Machine = loader_scene.instantiate() as Machine
	loader.body_id = "loader"
	loader.weight = 3
	loader.position = Vector2(80.0, 120.0)
	world.entities_container.add_child(loader)

	plate.check_weight()
	assert_true(plate.is_pressed)
	assert_true(door.is_open, "Plate reaching threshold must open linked door")
	assert_true(loader.get_meta("is_holding_latch", false), "Holding loader must be tagged is_holding_latch")
