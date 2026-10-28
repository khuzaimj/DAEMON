extends GutTest

func test_melee_swarmer_fsm_transitions() -> void:
	var file: FileAccess = FileAccess.open("res://data/ai/melee_swarmer.json", FileAccess.READ)
	assert_not_null(file, "melee_swarmer.json must exist")
	if file == null:
		return
	var json: JSON = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK)
	var preset: Dictionary = json.data as Dictionary

	var ai: AIController = autofree(AIController.new())
	ai.setup(preset)
	assert_eq(ai.current_state, "patrol", "Initial state must be patrol")

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var enemy: Machine = machine_scene.instantiate() as Machine
	enemy.position = Vector2(100, 100)
	enemy.facing = Vector2.DOWN
	add_child_autofree(enemy)

	var target: Machine = machine_scene.instantiate() as Machine
	target.position = Vector2(100, 150)
	add_child_autofree(target)

	# 1. In patrol, enemy spots target
	ai.update_senses(target, true, true, 1)
	var intent_chase: Intent = ai.decide(enemy, 1)
	assert_eq(ai.current_state, "chase", "Seeing target should transition to chase")

	# 2. In chase, target is close (within attack_range = 1.1 tiles = 17.6px)
	target.position = Vector2(100, 110) # 10px away
	ai.update_senses(target, true, true, 2)
	var intent_attack: Intent = ai.decide(enemy, 2)
	assert_eq(ai.current_state, "attack", "Close proximity should transition to attack")
	assert_true(intent_attack.primary, "Attack state must set intent.primary = true")

	# 3. Target moves out of range (60px away)
	target.position = Vector2(100, 160)
	ai.update_senses(target, true, true, 3)
	var intent_re_chase: Intent = ai.decide(enemy, 3)
	assert_eq(ai.current_state, "chase", "Moving out of range should transition back to chase")

	# 4. Target lost from vision
	ai.update_senses(target, false, false, 4)
	# Advance past lost_target threshold (60 ticks)
	var intent_search: Intent = ai.decide(enemy, 100)
	assert_eq(ai.current_state, "search", "Losing sight should transition to search")

	# 5. Search timeout (search_time = 4.0s = 240 ticks)
	ai.state_ticks = 245
	var intent_patrol: Intent = ai.decide(enemy, 400)
	assert_eq(ai.current_state, "patrol", "Search timeout should transition back to patrol")

func test_group_alert_propagation() -> void:
	var file: FileAccess = FileAccess.open("res://data/ai/melee_swarmer.json", FileAccess.READ)
	var json: JSON = JSON.new()
	json.parse(file.get_as_text())
	var preset: Dictionary = json.data as Dictionary

	var ally_ai: AIController = autofree(AIController.new())
	ally_ai.setup(preset)
	assert_eq(ally_ai.current_state, "patrol")

	# Receive alert from companion
	var alert_pos: Vector2 = Vector2(120, 80)
	ally_ai.receive_alert(alert_pos, null, 10)

	assert_eq(ally_ai.current_state, "chase", "Receiving group alert must transition patrol to chase")
	assert_eq(ally_ai.last_seen_pos, alert_pos, "Last seen position should match alert coordinate")
