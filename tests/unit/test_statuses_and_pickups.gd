extends GutTest

func test_overload_status_lifecycle() -> void:
	var state: BodyState = BodyState.new()
	state.max_integrity = 10
	state.current_integrity = 10
	assert_false(state.is_open(), "100% HP machine should not be open initially")
	assert_true(state.can_act(), "Normal machine should be able to act")

	# Apply overload for 120 ticks (2.0s)
	state.apply_status("overload", CombatMath.OVERLOAD_DURATION_TICKS)
	assert_true(state.has_status("overload"), "Status overload should be present")
	assert_true(state.is_open(), "Overload status must force is_open == true")
	assert_false(state.can_act(), "Overloaded machine cannot act")

	# Advance 60 ticks
	state.tick(60)
	assert_eq(state.get_status_duration("overload"), 60, "Overload duration should be 60 ticks remaining")
	assert_true(state.is_open())

	# Advance another 60 ticks -> should expire
	state.tick(60)
	assert_false(state.has_status("overload"), "Overload should expire after 120 ticks")
	assert_false(state.is_open(), "Full HP machine without overload should close")
	assert_true(state.can_act(), "Machine can act again after overload expires")

func test_stagger_status() -> void:
	var state: BodyState = BodyState.new()
	state.max_integrity = 10
	state.current_integrity = 10
	state.apply_status("stagger", CombatMath.STAGGER_DURATION_TICKS)
	assert_false(state.can_act(), "Staggered machine cannot act")

	state.tick(CombatMath.STAGGER_DURATION_TICKS)
	assert_false(state.has_status("stagger"), "Stagger should expire")
	assert_true(state.can_act(), "Machine can act after stagger")

func test_burn_damage_over_time() -> void:
	var state: BodyState = BodyState.new()
	state.max_integrity = 10
	state.current_integrity = 10
	state.apply_status("burn", CombatMath.BURN_DURATION_TICKS)

	# 30 ticks = 1 burn tick (1 damage)
	state.tick(30)
	assert_eq(state.current_integrity, 9, "Burn should inflict 1 thermal damage after 30 ticks")

	state.tick(30)
	assert_eq(state.current_integrity, 8, "Burn should inflict another 1 damage after 60 ticks")

func test_invulnerability_frames() -> void:
	var state: BodyState = BodyState.new()
	state.max_integrity = 10
	state.current_integrity = 10

	var hit1: bool = state.take_damage(2, "kinetic", false)
	assert_true(hit1, "First hit connects")
	assert_eq(state.current_integrity, 8)
	assert_eq(state.invulnerability_ticks, CombatMath.INVULNERABILITY_TICKS, "Should have 30 invulnerability ticks")

	# Immediate second hit should be ignored due to invulnerability
	var hit2: bool = state.take_damage(2, "kinetic", false)
	assert_false(hit2, "Hit during invulnerability frames should be ignored")
	assert_eq(state.current_integrity, 8, "Integrity unchanged during invulnerability")

	# Advance 30 ticks to expire invulnerability
	state.tick(30)
	assert_eq(state.invulnerability_ticks, 0, "Invulnerability expired")

	var hit3: bool = state.take_damage(2, "kinetic", false)
	assert_true(hit3, "Hit connects after invulnerability expires")
	assert_eq(state.current_integrity, 6)

func test_scrap_pickup_collection() -> void:
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node == null:
		return
	var initial_scrap: int = int(game_node.get("scrap"))

	var pickup: ScrapPickup = ScrapPickup.new()
	pickup.amount = 5
	add_child_autofree(pickup)

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var player_m: Machine = machine_scene.instantiate() as Machine
	player_m.operational_state = "player"
	add_child_autofree(player_m)

	pickup.collect(player_m)
	var final_scrap: int = int(game_node.get("scrap"))
	assert_eq(final_scrap, initial_scrap + 5, "Game scrap should increase by 5")

func test_combat_system_hostile_death_vs_player_crash() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	await get_tree().physics_frame

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")

	# 1. Hostile enemy at 0 integrity
	var enemy: Machine = machine_scene.instantiate() as Machine
	enemy.entity_id = "test_hostile_01"
	enemy.enemy_id = "rogue_janitor"
	enemy.operational_state = "hostile"
	enemy.faction = "hostile"
	enemy.enemy_data = { "drops": { "scrap": [2, 4] } }
	world.entities_container.add_child(enemy)
	world.register_machine(enemy)
	enemy.state.current_integrity = 0
	enemy.state.is_crashed = true

	# 2. Parked friendly machine at 0 integrity
	var parked: Machine = machine_scene.instantiate() as Machine
	parked.entity_id = "test_parked_01"
	parked.operational_state = "parked"
	parked.faction = "player"
	world.entities_container.add_child(parked)
	world.register_machine(parked)
	parked.state.current_integrity = 0

	# Step combat system
	var combat_sys: CombatSystem = CombatSystem.new()
	combat_sys.step(world, 1, 0.0166)

	# Verify hostile is queued for free and not in world.machines
	assert_false(world.machines.has(enemy), "Destroyed hostile machine should be unregistered from world")
	assert_true(enemy.is_queued_for_deletion(), "Destroyed hostile machine should be queued for deletion")

	# Verify parked machine is NOT deleted and remains as Crashed
	assert_true(world.machines.has(parked), "Parked crashed machine remains registered in world")
	assert_false(parked.is_queued_for_deletion(), "Parked crashed machine should not be deleted")
	assert_true(parked.state.is_crashed, "Parked machine state must be marked crashed")
