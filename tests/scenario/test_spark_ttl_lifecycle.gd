extends GutTest

func test_spark_ttl_conduit_pauses_drain() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_02") # Contains conduits ':'

	assert_not_null(world.player_machine)
	assert_eq(world.hijack_fsm.state, HijackFSM.State.CURSOR)
	world.hijack_fsm.pause_ttl_until_hijack = false
	world.hijack_fsm.refill_ttl()

	var initial_ttl: int = world.hijack_fsm.ttl_ticks
	assert_eq(initial_ttl, HijackFSM.BASE_TTL_TICKS)

	# 1. On normal floor, stepping physics process drains TTL
	world.player_machine.position = Vector2(100.0, 100.0) # floor
	for _i: int in range(30):
		world._physics_process(1.0 / 60.0)

	assert_lt(world.hijack_fsm.ttl_ticks, initial_ttl, "Exposed cursor on floor must drain TTL")
	var floor_ttl: int = world.hijack_fsm.ttl_ticks

	# 2. Inside conduit ':', stepping physics process pauses TTL drain
	# In debug_02 grid row 7 col 29 is exit / row 1 has conduit ':'
	# Place player on a known conduit tile in debug_02 (cols 20-22, row 7 is col 21, row 7 in debug_02)
	# Set tile at cell (10, 5) to ':' for deterministic test
	world.active_room.set_tile_at(Vector2i(10, 5), ":")
	world.player_machine.position = Vector2(10 * 16 + 8, 5 * 16 + 8)

	for _i: int in range(30):
		world._physics_process(1.0 / 60.0)

	assert_eq(world.hijack_fsm.ttl_ticks, floor_ttl, "Cursor inside conduit must NOT drain TTL")

func test_ttl_expiry_and_cursor_crash_triggers_reboot_at_dock() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.call("reset")
		game.set("scrap", 42)
		game.set("last_dock_room_id", "debug_01")
		game.set("last_dock_spawn_pos", Vector2(80.0, 80.0))

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_05")

	var reboots: Array[String] = []
	var events: Node = get_node_or_null("/root/Events")
	if events != null:
		events.connect("reboot_triggered", func(r: String) -> void: reboots.append(r))

	world.hijack_fsm.pause_ttl_until_hijack = false
	world.hijack_fsm.ttl_ticks = 2 # 2 ticks to expiry

	world._physics_process(1.0 / 60.0)
	world._physics_process(1.0 / 60.0)

	assert_true(reboots.has("ttl_expired"), "TTL reaching 0 must emit reboot_triggered('ttl_expired')")
	assert_eq(world.current_room_id, "debug_01", "Reboot must load last dock room")
	assert_almost_eq(world.player_machine.position.x, 80.0, 0.5, "Reboot must place cursor at last dock position")
	assert_eq(world.hijack_fsm.ttl_ticks, HijackFSM.BASE_TTL_TICKS, "Reboot must refill TTL")
	if game != null:
		assert_eq(int(game.get("scrap")), 42, "Scrap must be preserved across reboot")

	# Test cursor crash reboot
	reboots.clear()
	world.player_machine.take_damage(10, "kinetic", true) # Lethal to 2HP Cursor
	world._physics_process(1.0 / 60.0)

	assert_true(reboots.has("cursor_destroyed"), "Cursor crash must trigger reboot")

func test_ttl_upgrades_math() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	assert_eq(fsm.max_ttl_ticks, 480) # 8.0s

	fsm.ttl_upgrades = 1
	fsm.recalculate_max_ttl()
	assert_eq(fsm.max_ttl_ticks, 660) # +3.0s = 11.0s

	fsm.ttl_upgrades = 4 # Max 4 upgrades -> 20.0s = 1200 ticks
	fsm.recalculate_max_ttl()
	assert_eq(fsm.max_ttl_ticks, 1200)

	fsm.ttl_upgrades = 10 # Capped at MAX_TTL_CAP_TICKS
	fsm.recalculate_max_ttl()
	assert_eq(fsm.max_ttl_ticks, 1200)
