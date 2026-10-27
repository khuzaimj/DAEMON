extends GutTest

func test_intent_clone_and_reset() -> void:
	var intent: Intent = Intent.new()
	intent.move = Vector2(1, 0)
	intent.primary = true
	var cloned: Intent = intent.clone()
	assert_eq(cloned.move, Vector2(1, 0))
	assert_true(cloned.primary)
	intent.reset()
	assert_eq(intent.move, Vector2.ZERO)
	assert_false(intent.primary)

func test_rng_streams_determinism() -> void:
	var s1: RngStreams = RngStreams.new(42)
	var s2: RngStreams = RngStreams.new(42)
	var r1: RandomNumberGenerator = s1.get_stream("combat")
	var r2: RandomNumberGenerator = s2.get_stream("combat")
	assert_eq(r1.randi(), r2.randi())
	assert_eq(r1.randf(), r2.randf())

func test_grid_coordinates() -> void:
	var cell: Vector2i = Vector2i(2, 3)
	var pixel: Vector2 = Grid.tile_to_pixel(cell)
	assert_eq(pixel, Vector2(40, 56))
	var round_trip_cell: Vector2i = Grid.pixel_to_tile(pixel)
	assert_eq(round_trip_cell, cell)
	assert_true(Grid.is_in_room_bounds(Vector2i(0, 0)))
	assert_true(Grid.is_in_room_bounds(Vector2i(29, 14)))
	assert_false(Grid.is_in_room_bounds(Vector2i(30, 14)))
	assert_false(Grid.is_in_room_bounds(Vector2i(-1, 0)))

func test_schema_helpers() -> void:
	assert_true(Schema.is_snake_case("loader"))
	assert_true(Schema.is_snake_case("rogue_janitor"))
	assert_false(Schema.is_snake_case("RogueJanitor"))
	assert_false(Schema.is_snake_case("rogue-janitor"))
	var data: Dictionary = { "name": "test", "_comment": "ok", "invalid": 123 }
	var errs: Array[String] = Schema.validate_keys(data, ["name"], "item")
	assert_eq(errs.size(), 1)
