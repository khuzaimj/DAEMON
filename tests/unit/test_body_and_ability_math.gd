extends GutTest

func test_body_state_heat_cooling() -> void:
	var state: BodyState = BodyState.new()
	state.setup_from_dict({
		"integrity": 10,
		"heat_max": 100,
		"heat_cooldown": 20
	})
	
	state.add_heat(50.0)
	assert_almost_eq(state.current_heat, 50.0, 0.001, "Heat should be 50.0")
	
	# 60 ticks = 1 second. At 20/s, should cool by 20 -> 30.0
	state.tick(60)
	assert_almost_eq(state.current_heat, 30.0, 0.01, "Heat should cool to 30.0 after 1s")
	
	# Another 90 ticks = 1.5s -> 30.0 cooled -> should clamp to 0.0
	state.tick(90)
	assert_almost_eq(state.current_heat, 0.0, 0.001, "Heat should clamp to 0.0")

func test_body_state_overheat_lockout() -> void:
	var state: BodyState = BodyState.new()
	state.setup_from_dict({
		"integrity": 10,
		"heat_max": 100,
		"heat_cooldown": 20
	})
	
	state.add_heat(100.0)
	assert_true(state.is_overheated, "Reaching 100 heat triggers overheat")
	assert_eq(state.overheat_timer_ticks, 180, "Overheat lockout is 180 ticks (3s)")
	assert_false(state.can_act(), "Overheated machine cannot act")
	
	# Advance 100 ticks (still overheated)
	state.tick(100)
	assert_true(state.is_overheated, "Still overheated at 100 ticks")
	assert_false(state.can_act(), "Still cannot act")
	
	# Advance 80 ticks (180 total)
	state.tick(80)
	assert_false(state.is_overheated, "Overheat clears after 180 ticks")
	assert_true(state.can_act(), "Machine can act after overheat recovery")

func test_body_state_integrity_and_crash() -> void:
	var state: BodyState = BodyState.new()
	state.setup_from_dict({
		"integrity": 10,
		"heat_max": 100,
		"heat_cooldown": 20
	})
	
	assert_true(state.can_act())
	assert_false(state.is_crashed)
	
	# Take 4 damage
	var damaged: bool = state.take_damage(4)
	assert_true(damaged)
	assert_eq(state.current_integrity, 6)
	assert_eq(state.invulnerability_ticks, 30, "Damage sets 30 ticks of invulnerability (0.5s)")
	
	# Immediate damage during invulnerability is ignored
	var blocked: bool = state.take_damage(3)
	assert_false(blocked, "Damage blocked by invulnerability")
	assert_eq(state.current_integrity, 6)
	
	# Expire invulnerability
	state.tick(30)
	assert_eq(state.invulnerability_ticks, 0)
	
	# Take lethal damage
	state.take_damage(6)
	assert_eq(state.current_integrity, 0)
	assert_true(state.is_crashed, "0 integrity sets is_crashed = true")
	assert_false(state.can_act(), "Crashed machine cannot act")
	
	# Repair clears crash
	state.repair(4)
	assert_eq(state.current_integrity, 4)
	assert_false(state.is_crashed, "Repair clears crashed status")
	assert_true(state.can_act())

func test_body_state_statuses_and_open() -> void:
	var state: BodyState = BodyState.new()
	state.setup_from_dict({
		"integrity": 10,
		"heat_max": 100,
		"heat_cooldown": 20
	})
	
	# Stun status
	state.apply_status("stun", 60)
	assert_true(state.has_status("stun"))
	assert_false(state.can_act(), "Stunned machine cannot act")
	state.tick(60)
	assert_false(state.has_status("stun"), "Stun expires after 60 ticks")
	assert_true(state.can_act())
	
	# Overload status opens target
	assert_false(state.is_open())
	state.apply_status("overload", 60)
	assert_true(state.has_status("overload"))
	assert_true(state.is_open(), "Overloaded target is open for hijack")
	state.tick(60)
	assert_false(state.is_open())
	
	# Low integrity (<= 35%) also opens target
	state.take_damage(7, "kinetic", true) # 3 / 10 = 30% <= 35%
	assert_eq(state.current_integrity, 3)
	assert_true(state.is_open(), "Integrity <= 35% makes machine open")
	
	# Burn damage over time
	state.repair(7) # Back to 10
	state.apply_status("burn", 60)
	state.tick(30) # Triggers 1 burn damage tick
	assert_eq(state.current_integrity, 9)
	state.tick(30) # Triggers 2nd burn damage tick
	assert_eq(state.current_integrity, 8)
	state.tick(1)
	assert_false(state.has_status("burn"))

func test_ability_math() -> void:
	assert_eq(AbilityMath.seconds_to_ticks(1.5), 90)
	assert_almost_eq(AbilityMath.ticks_to_seconds(90), 1.5, 0.001)
	
	var origin: Vector2 = Vector2(100, 100)
	var facing: Vector2 = Vector2.RIGHT
	
	# Target in front within 90 deg arc and 50px radius
	var target_in_front: Vector2 = Vector2(130, 100)
	assert_true(AbilityMath.is_point_in_arc(origin, facing, target_in_front, 90.0, 50.0))
	
	# Target behind
	var target_behind: Vector2 = Vector2(70, 100)
	assert_false(AbilityMath.is_point_in_arc(origin, facing, target_behind, 90.0, 50.0))
	
	# Target out of range
	var target_far: Vector2 = Vector2(200, 100)
	assert_false(AbilityMath.is_point_in_arc(origin, facing, target_far, 90.0, 50.0))
	
	# Knockback calculation
	var kb: Vector2 = AbilityMath.calculate_knockback(origin, target_in_front, 4.0)
	assert_almost_eq(kb.x, 4.0, 0.001)
	assert_almost_eq(kb.y, 0.0, 0.001)
	
	# Snap to 8-way
	assert_eq(AbilityMath.snap_to_8_way(Vector2(0.9, 0.1)), Vector2.RIGHT)
	assert_eq(AbilityMath.snap_to_8_way(Vector2(0.1, 0.9)), Vector2.DOWN)
	
	# Facing to sheet direction
	assert_eq(AbilityMath.facing_to_sheet_direction(Vector2.DOWN), "down")
	assert_eq(AbilityMath.facing_to_sheet_direction(Vector2.UP), "up")
	assert_eq(AbilityMath.facing_to_sheet_direction(Vector2.RIGHT), "side")
	assert_eq(AbilityMath.facing_to_sheet_direction(Vector2.LEFT), "side")
