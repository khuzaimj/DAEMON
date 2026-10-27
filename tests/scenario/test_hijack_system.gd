extends GutTest

func test_world_hijack_targeting_and_slow_mo() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	assert_not_null(world.player_machine)
	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001)

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# 1. Trigger hop to enter targeting
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TARGETING)
	assert_almost_eq(Engine.time_scale, 0.25, 0.001, "Engine time scale must slow to 0.25 during targeting")

	# 2. Cancel via handle_back_input (Guardrail 1: ESC cancels targeting)
	var handled: bool = world.handle_back_input()
	assert_true(handled, "Back input must handle and cancel targeting")
	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Time scale restored to 1.0 on cancel")

func test_world_hijack_transit_and_host_seizure() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	# Spawn a dormant target machine close to player (within link range 80px)
	var target_scene: PackedScene = load("res://scenes/machine.tscn")
	var target: Machine = target_scene.instantiate() as Machine
	target.entity_id = "test_janitor"
	target.body_id = "janitor"
	target.position = world.player_machine.position + Vector2(32.0, 0.0)
	target.operational_state = "dormant"
	world.entities_container.add_child(target)
	world.register_machine(target)

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	world.player_machine.controller = script_ctrl

	# Enter targeting
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TARGETING)
	assert_eq(world.hijack_fsm.selected_target_id, "test_janitor")

	# Confirm hop
	script_ctrl.default_intent.hop = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.hop = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.TRANSIT)

	# Step transit to completion (32px at 320px/s is 0.1s = 6 ticks)
	for _i: int in range(10):
		world._physics_process(1.0 / 60.0)

	assert_eq(world.hijack_fsm.state, HijackFSM.State.HOSTED)
	assert_eq(world.player_machine, target, "Player machine should be swapped to target")
	assert_eq(target.operational_state, "player")
	assert_true(target.controller is PlayerController)

func test_world_voluntary_and_forced_eject() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	# Host player in a loader machine
	var loader_scene: PackedScene = load("res://scenes/machine.tscn")
	var loader: Machine = loader_scene.instantiate() as Machine
	loader.entity_id = "test_loader"
	loader.body_id = "loader"
	loader.position = Vector2(100.0, 100.0)
	loader.operational_state = "player"
	world.entities_container.add_child(loader)
	world.register_machine(loader)
	world.player_machine = loader
	world.hijack_fsm.state = HijackFSM.State.HOSTED
	world.hijack_fsm.current_host_id = "test_loader"

	var script_ctrl: ScriptController = autofree(ScriptController.new()) as ScriptController
	loader.controller = script_ctrl

	# 1. Voluntary eject via hold-complete intent
	script_ctrl.default_intent.eject = true
	world._physics_process(1.0 / 60.0)
	script_ctrl.default_intent.eject = false

	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR)
	assert_eq(loader.operational_state, "parked", "Old host should become parked")
	assert_eq(world.player_machine.body_id, "cursor", "Player should now pilot cursor")

	# 2. Host loader again and test forced eject on overheat
	world.player_machine = loader
	loader.operational_state = "player"
	loader.controller = script_ctrl
	world.hijack_fsm.state = HijackFSM.State.HOSTED
	world.hijack_fsm.current_host_id = "test_loader"

	loader.state.current_heat = 100.0
	loader.state.is_overheated = true
	loader.state.overheat_timer_ticks = 180
	world._physics_process(1.0 / 60.0)

	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR, "Overheated host forces eject")
	assert_eq(world.player_machine.body_id, "cursor")
