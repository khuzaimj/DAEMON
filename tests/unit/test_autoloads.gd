extends GutTest

func test_events_signal_emission() -> void:
	var received: Array[int] = []
	Events.tick_advanced.connect(func(t: int) -> void: received.append(t))
	Game.reset()
	Game.advance_tick()
	Game.advance_tick()
	assert_eq(received.size(), 2)
	assert_eq(Game.tick, 2)

func test_game_pause_blocks_tick() -> void:
	Game.reset()
	Game.paused = true
	Game.advance_tick()
	assert_eq(Game.tick, 0)
	Game.paused = false
	Game.advance_tick()
	assert_eq(Game.tick, 1)

func test_data_cache_operation() -> void:
	Data.clear_cache()
	var missing: Variant = Data.get_json("res://nonexistent.json")
	assert_null(missing)
