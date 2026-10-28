class_name TestBossFight
extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autofree(world)
	world.load_room("debug_10")

func test_bootloader_boss_lifecycle_and_subsystem_hijacking() -> void:
	assert_not_null(world.active_boss_controller, "Boss controller should be active in debug_10")
	var b_ctrl: BossController = world.active_boss_controller
	assert_eq(b_ctrl.boss_id, "bootloader")
	assert_eq(b_ctrl.subsystems.size(), 3, "Bootloader should have 3 actuators")

	var boss_machine: Machine = b_ctrl.boss_machine
	assert_not_null(boss_machine)
	assert_true(boss_machine.is_boss_body, "Core boss body must be flagged is_boss_body")

	# 1. Verify core boss body cannot be hijacked
	var candidates: Array[Dictionary] = world._get_hijack_candidates(Vector2(50, 70))
	for c: Dictionary in candidates:
		if c.get("id") == "bootloader":
			assert_false(HijackFSM.is_candidate_valid(c, Vector2(50, 70), 300.0, 0), "Boss core body cannot be hijacked")

	# 2. Phase 1: actuator_1 is active and open, others are locked
	var act1: Subsystem = b_ctrl.subsystems[0]
	var act2: Subsystem = b_ctrl.subsystems[1]
	var act3: Subsystem = b_ctrl.subsystems[2]

	assert_true(act1.is_open(), "Actuator 1 should be open in Phase 1")
	assert_false(act2.is_open(), "Actuator 2 should be locked in Phase 1")
	assert_false(act3.is_open(), "Actuator 3 should be locked in Phase 1")

	# Step world ticks to verify slam attack pattern
	var initial_projs: int = world.projectiles.size()
	for i: int in range(125):
		world._physics_process(1.0 / 60.0)
	assert_gt(world.projectiles.size(), initial_projs, "Boss slam should launch shockwave projectiles")

	# 3. Hijack actuator 1
	world.player_machine.position = act1.position + Vector2(-16, 0)
	world._on_host_seized(act1.entity_id, "actuator")

	assert_true(act1.is_disabled, "Actuator 1 should be disabled after hijack")
	assert_eq(b_ctrl.current_phase_index, 1, "Boss should advance to Phase 2")
	assert_true(act2.is_open(), "Actuator 2 should be open in Phase 2")
	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR, "Player should be ejected to cursor after subsystem overload")

	# 4. Hijack actuator 2
	world._on_host_seized(act2.entity_id, "actuator")
	assert_true(act2.is_disabled, "Actuator 2 should be disabled")
	assert_eq(b_ctrl.current_phase_index, 2, "Boss should advance to Phase 3")
	assert_true(act3.is_open(), "Actuator 3 should be open in Phase 3")

	# 5. Hijack actuator 3 -> Boss defeated
	var defeated_events: Array[String] = []
	b_ctrl.boss_defeated.connect(func(b_id: String, reward: String) -> void:
		assert_eq(b_id, "bootloader")
		assert_eq(reward, "clearance_l1")
		defeated_events.append(b_id)
	)

	world._on_host_seized(act3.entity_id, "actuator")
	assert_true(act3.is_disabled, "Actuator 3 should be disabled")
	assert_true(b_ctrl.is_defeated, "Boss should be marked defeated")
	assert_gt(defeated_events.size(), 0, "boss_defeated signal should be emitted")
	assert_eq(boss_machine.operational_state, "dormant", "Boss should power down to dormant upon defeat")
