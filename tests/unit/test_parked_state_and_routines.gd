extends GutTest

func test_parked_state_and_patrol_reversal() -> void:
	var state: ParkedState = ParkedState.new("patrol", Vector2(100, 100), Vector2(180, 100), Vector2.RIGHT)
	assert_eq(state.routine, "patrol")
	assert_eq(state.get_current_patrol_target(), Vector2(180, 100), "Initial patrol target is pin_pos")

	# Not yet arrived
	state.check_patrol_arrival(Vector2(140, 100))
	assert_true(state.patrol_forward)
	assert_eq(state.get_current_patrol_target(), Vector2(180, 100))

	# Arrived at pin_pos (within 4px)
	state.check_patrol_arrival(Vector2(179, 100))
	assert_false(state.patrol_forward, "Arriving at pin must reverse patrol to origin")
	assert_eq(state.get_current_patrol_target(), Vector2(100, 100))

	# Arrived back at origin
	state.check_patrol_arrival(Vector2(101, 100))
	assert_true(state.patrol_forward, "Arriving back at origin must reverse patrol to pin")
	assert_eq(state.get_current_patrol_target(), Vector2(180, 100))

func test_routine_controller_hold_and_repeat() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var m: Machine = autofree(machine_scene.instantiate()) as Machine
	m.position = Vector2(100, 100)
	m.facing = Vector2.UP

	# 1. HOLD routine
	var hold_state: ParkedState = ParkedState.new("hold", m.position, m.position + Vector2(0, 80), Vector2.UP)
	var ctrl: RoutineController = autofree(RoutineController.new(hold_state)) as RoutineController

	var intent: Intent = ctrl.decide(m, 1)
	assert_eq(intent.move, Vector2.ZERO)
	assert_false(intent.primary, "HOLD must not use primary ability")
	assert_eq(intent.aim, Vector2.UP)

	# 2. REPEAT routine
	hold_state.routine = "repeat"
	var rep_intent: Intent = ctrl.decide(m, 2)
	assert_eq(rep_intent.move, Vector2.ZERO)
	assert_true(rep_intent.primary, "REPEAT must continuously use primary ability")
	assert_eq(rep_intent.aim, Vector2.UP)

func test_routine_controller_guard_and_patrol() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var sentry_scene: PackedScene = load("res://scenes/machine.tscn")
	var sentry: Machine = sentry_scene.instantiate() as Machine
	sentry.entity_id = "guard_sentry"
	sentry.body_id = "sentry"
	sentry.position = Vector2(40.0, 120.0)
	sentry.operational_state = "parked"
	world.entities_container.add_child(sentry)
	world.register_machine(sentry)

	# 1. GUARD with no hostiles around
	var guard_state: ParkedState = ParkedState.new("guard", sentry.position, sentry.position, Vector2.RIGHT)
	var r_ctrl: RoutineController = autofree(RoutineController.new(guard_state)) as RoutineController
	sentry.controller = r_ctrl

	var intent1: Intent = r_ctrl.decide(sentry, 1)
	assert_false(intent1.primary, "GUARD with no hostiles must not fire")

	# Spawn hostile rogue janitor 40px to the right (clear floor in row 7)
	var hostile_scene: PackedScene = load("res://scenes/machine.tscn")
	var hostile: Machine = hostile_scene.instantiate() as Machine
	hostile.entity_id = "rogue_1"
	hostile.operational_state = "hostile"
	hostile.position = Vector2(80.0, 120.0)
	world.entities_container.add_child(hostile)
	world.register_machine(hostile)

	# GUARD detects hostile and fires
	var intent2: Intent = r_ctrl.decide(sentry, 2)
	assert_true(intent2.primary, "GUARD detecting hostile in range and LOS must fire")
	assert_almost_eq(intent2.aim.x, 1.0, 0.01, "GUARD must aim toward hostile")

	# 2. PATROL between (40, 120) and (80, 120)
	hostile.operational_state = "dormant" # disarm hostile
	guard_state.routine = "patrol"
	guard_state.park_origin_pos = Vector2(40.0, 120.0)
	guard_state.pin_pos = Vector2(80.0, 120.0)
	guard_state.patrol_forward = true

	var pat_intent: Intent = r_ctrl.decide(sentry, 3)
	assert_gt(pat_intent.move.x, 0.0, "PATROL must move toward target pin")

func test_medic_repeat_heal_passive() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")

	# Parked damaged loader at (100, 100)
	var patient: Machine = machine_scene.instantiate() as Machine
	patient.entity_id = "damaged_loader"
	patient.body_id = "loader"
	patient.position = Vector2(100, 100)
	patient.operational_state = "parked"
	patient.state.max_integrity = 14
	patient.state.current_integrity = 8
	world.entities_container.add_child(patient)
	world.register_machine(patient)

	# Parked medic on REPEAT at (120, 100) (20px away <= 48px radius)
	var medic: Machine = machine_scene.instantiate() as Machine
	medic.entity_id = "parked_medic"
	medic.body_id = "medic"
	medic.passives = ["repeat_heal"]
	medic.position = Vector2(120, 100)
	medic.operational_state = "parked"
	world.entities_container.add_child(medic)
	world.register_machine(medic)

	var p_state: ParkedState = ParkedState.new("repeat", medic.position, medic.position, Vector2.LEFT)
	var r_ctrl: RoutineController = autofree(RoutineController.new(p_state)) as RoutineController
	medic.controller = r_ctrl

	# Run 60 ticks to trigger medic periodic heal (1.0s interval)
	for t: int in range(1, 62):
		r_ctrl.decide(medic, t)

	assert_gt(patient.state.current_integrity, 8, "Medic on REPEAT must heal nearby damaged parked host")
	assert_eq(patient.state.current_integrity, 10)
