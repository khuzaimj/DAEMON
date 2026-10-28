class_name TestTerrainHazards
extends GutTest

var _tiles_def: Dictionary = {
	"}": { "name": "belt_e", "push": [1, 0] },
	"{": { "name": "belt_w", "push": [-1, 0] },
	"A": { "name": "belt_n", "push": [0, -1] },
	"V": { "name": "belt_s", "push": [0, 1] },
	"=": { "name": "electrified", "hazard": "electric" },
	"M": { "name": "magnetic", "solid": true, "magnetic": true },
	"-": { "name": "collapsing", "hazard": "collapsing" },
	"^": { "name": "spikes", "hazard": "spikes" },
	"~": { "name": "coolant", "medium": "liquid" },
	"o": { "name": "pit", "medium": "void" },
	".": { "name": "floor" }
}

func test_terrain_rules_conveyor_push() -> void:
	var push_e: Vector2 = TerrainRules.calculate_conveyor_push("}", _tiles_def, 32.0)
	assert_eq(push_e, Vector2(32.0, 0.0), "East belt pushes +X")
	var push_w: Vector2 = TerrainRules.calculate_conveyor_push("{", _tiles_def, 32.0)
	assert_eq(push_w, Vector2(-32.0, 0.0), "West belt pushes -X")
	var push_n: Vector2 = TerrainRules.calculate_conveyor_push("A", _tiles_def, 32.0)
	assert_eq(push_n, Vector2(0.0, -32.0), "North belt pushes -Y")
	var push_s: Vector2 = TerrainRules.calculate_conveyor_push("V", _tiles_def, 32.0)
	assert_eq(push_s, Vector2(0.0, 32.0), "South belt pushes +Y")
	var push_none: Vector2 = TerrainRules.calculate_conveyor_push(".", _tiles_def, 32.0)
	assert_eq(push_none, Vector2.ZERO, "Normal floor has no conveyor push")

func test_terrain_rules_immunities_and_traversals() -> void:
	assert_true(TerrainRules.should_ignore_conveyor(["hover"]), "Drone ignores conveyors")
	assert_false(TerrainRules.should_ignore_conveyor(["ground"]), "Ground units do not ignore conveyors")

	assert_true(TerrainRules.is_insulated(["insulated"], "crawler"), "Crawler is insulated")
	assert_true(TerrainRules.is_insulated(["insulated"], "other"), "Insulated passive is insulated")
	assert_false(TerrainRules.is_insulated([], "janitor"), "Janitor is not insulated")

	assert_true(TerrainRules.can_traverse_magnetic([], true, "crawler"), "Cling status allows magnetic wall traversal")
	assert_true(TerrainRules.can_traverse_magnetic(["cling"], false, "crawler"), "Cling passive allows magnetic wall traversal")
	assert_false(TerrainRules.can_traverse_magnetic([], false, "crawler"), "Crawler without cling blocked by magnetic wall")

	assert_true(TerrainRules.can_safely_cross_collapsing([], ["hover"], "drone"), "Drone hovers over collapsing floor")
	assert_true(TerrainRules.can_safely_cross_collapsing(["collapse_cross"], [], "courier"), "Courier crosses safely")
	assert_false(TerrainRules.can_safely_cross_collapsing([], ["ground"], "loader"), "Loader triggers collapse")

func test_collapsing_flood_fill_region() -> void:
	var grid: Array[String] = [
		"...",
		".--",
		".-."
	]
	var region: Array[Vector2i] = TerrainRules.get_connected_collapse_region(grid, Vector2i(1, 1))
	assert_eq(region.size(), 3, "Connected region has 3 cells")
	assert_true(region.has(Vector2i(1, 1)))
	assert_true(region.has(Vector2i(2, 1)))
	assert_true(region.has(Vector2i(1, 2)))

func test_room_runtime_magnetic_collision_and_collapsing() -> void:
	var runtime: RoomRuntime = RoomRuntime.new()
	add_child_autofree(runtime)

	var room_dict: Dictionary = {
		"id": "test_hazards",
		"grid": [
			"##############################",
			"#...M---.....................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"##############################"
		]
	}
	runtime.setup(room_dict)

	assert_not_null(runtime._static_body_magnetic, "Magnetic static body created")
	assert_eq(runtime._static_body_magnetic.collision_layer, 1 << (11 - 1), "Magnetic body on layer 11")

	# Trigger collapse on (5, 1) which is '-'
	runtime.trigger_collapse(Vector2i(5, 1))
	assert_eq(runtime._collapsing_regions.size(), 1, "One collapsing region active")
	var reg: Dictionary = runtime._collapsing_regions[0]
	assert_eq(reg["cells"].size(), 3, "3 connected collapsing cells")

	# Step collapse until delay expires
	var delay: int = int(reg["ticks_left"])
	for i: int in range(delay):
		runtime.step_collapsing(null)

	assert_eq(runtime._collapsing_regions.size(), 0, "Region completed")
	assert_eq(runtime.grid[1][5], "o", "Cell (5, 1) converted to pit 'o'")
	assert_eq(runtime.grid[1][6], "o", "Cell (6, 1) converted to pit 'o'")
	assert_eq(runtime.grid[1][7], "o", "Cell (7, 1) converted to pit 'o'")

func test_machine_hazards_and_conveyors() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn") as PackedScene
	var m: Machine = machine_scene.instantiate() as Machine
	add_child_autofree(m)
	m.apply_body_data({
		"id": "janitor",
		"size": "S",
		"weight": 1,
		"speed": 3.0,
		"integrity": 6,
		"heat_max": 100,
		"primary": "sweep",
		"secondary": "dash",
		"passives": [],
		"medium": ["ground"]
	})

	var runtime: RoomRuntime = RoomRuntime.new()
	add_child_autofree(runtime)
	runtime.setup({
		"id": "test_room",
		"grid": [
			"##############################",
			"#...}........................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"##############################"
		]
	})
	m.current_room = runtime
	m.global_position = Grid.tile_to_pixel_center(Vector2i(4, 1)) # on '}' belt_e

	# Machine steps movement with 0 intent, should receive conveyor push
	m.current_intent = Intent.new()
	m.step_movement(1.0 / 60.0)
	assert_gt(m.velocity.x, 0.0, "Conveyor pushed machine east")
