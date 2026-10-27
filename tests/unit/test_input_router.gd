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

func test_input_router_defaults() -> void:
	InputRouter.sample_input()
	assert_eq(InputRouter.move, Vector2.ZERO)
	assert_false(InputRouter.primary)
	assert_false(InputRouter.hop)
	assert_false(InputRouter.eject)
