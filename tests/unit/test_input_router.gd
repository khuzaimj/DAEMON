extends GutTest

func test_actions_registered() -> void:
	assert_true(InputMap.has_action("move_up"))
	assert_true(InputMap.has_action("move_down"))
	assert_true(InputMap.has_action("move_left"))
	assert_true(InputMap.has_action("move_right"))
	assert_true(InputMap.has_action("primary"))
	assert_true(InputMap.has_action("secondary"))
	assert_true(InputMap.has_action("hop"))
	assert_true(InputMap.has_action("routine"))
	assert_true(InputMap.has_action("interact"))
	assert_true(InputMap.has_action("back"))

	# Verify joypad button and motion events are bound
	var primary_events: Array[InputEvent] = InputMap.action_get_events("primary")
	var has_joy_button: bool = false
	for ev: InputEvent in primary_events:
		if ev is InputEventJoypadButton:
			has_joy_button = true
			break
	assert_true(has_joy_button, "primary action must have joypad button mapped")

	var move_up_events: Array[InputEvent] = InputMap.action_get_events("move_up")
	var has_joy_axis: bool = false
	for ev: InputEvent in move_up_events:
		if ev is InputEventJoypadMotion:
			has_joy_axis = true
			break
	assert_true(has_joy_axis, "move_up action must have joypad motion mapped")

func test_input_router_defaults_and_reset() -> void:
	InputRouter.sample_input()
	assert_eq(InputRouter.move, Vector2.ZERO)
	assert_false(InputRouter.primary)
	assert_false(InputRouter.hop)
	assert_false(InputRouter.eject)

	# Test reset_input
	InputRouter.move = Vector2(1, 0)
	InputRouter.aim = Vector2(1, 0)
	InputRouter.reset_input()
	assert_eq(InputRouter.move, Vector2.ZERO, "reset_input must zero move")
	assert_eq(InputRouter.aim, Vector2.ZERO, "reset_input must zero aim")
