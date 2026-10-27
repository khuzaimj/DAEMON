class_name RoomRuntime
extends Node2D

var room_data: Dictionary = {}
var room_id: String = ""
var exits: Dictionary = {}
var grid: Array[String] = []

var _tiles_def: Dictionary = {}
var _static_body_solid: StaticBody2D
var _static_body_conduit: StaticBody2D

func setup(data: Dictionary) -> void:
	room_data = data
	room_id = data.get("id", "")
	exits = data.get("exits", {})
	grid.clear()
	var raw_grid: Array = data.get("grid", [])
	for row: Variant in raw_grid:
		grid.append(str(row))
	_load_tiles_def()
	_build_collision()
	queue_redraw()

func _load_tiles_def() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var root: Window = (main_loop as SceneTree).root
		if root != null:
			var data_node: Node = root.get_node_or_null("Data")
			if data_node != null and data_node.has_method("get_json"):
				var raw: Variant = data_node.call("get_json", "res://data/tiles.json")
				if raw is Dictionary:
					_tiles_def = (raw as Dictionary).get("tiles", {})
					return
	if FileAccess.file_exists("res://data/tiles.json"):
		var file: FileAccess = FileAccess.open("res://data/tiles.json", FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_tiles_def = (json.data as Dictionary).get("tiles", {})

func _build_collision() -> void:
	if _static_body_solid != null:
		_static_body_solid.queue_free()
	if _static_body_conduit != null:
		_static_body_conduit.queue_free()

	_static_body_solid = StaticBody2D.new()
	_static_body_solid.name = "CollisionSolid"
	_static_body_solid.collision_layer = 1 # Layer 1: solid
	_static_body_solid.collision_mask = 0
	add_child(_static_body_solid)

	_static_body_conduit = StaticBody2D.new()
	_static_body_conduit.name = "CollisionConduit"
	_static_body_conduit.collision_layer = 2 # Layer 2: conduit_gate
	_static_body_conduit.collision_mask = 0
	add_child(_static_body_conduit)

	_generate_merged_runs(_static_body_solid, func(glyph: String) -> bool:
		var def: Dictionary = _tiles_def.get(glyph, {})
		return def.get("solid", false)
	)
	_generate_merged_runs(_static_body_conduit, func(glyph: String) -> bool:
		var def: Dictionary = _tiles_def.get(glyph, {})
		return def.get("fits", "") == "xs"
	)

func _generate_merged_runs(body: StaticBody2D, match_fn: Callable) -> void:
	for y: int in range(grid.size()):
		var row: String = grid[y]
		var run_start: int = -1
		for x: int in range(row.length()):
			var glyph: String = row[x]
			var is_match: bool = match_fn.call(glyph)
			if is_match:
				if run_start == -1:
					run_start = x
			else:
				if run_start != -1:
					_add_box_shape(body, run_start, y, x - run_start)
					run_start = -1
		if run_start != -1:
			_add_box_shape(body, run_start, y, row.length() - run_start)

func _add_box_shape(body: StaticBody2D, start_x: int, y: int, length: int) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	var width: float = length * Grid.TILE_SIZE
	var height: float = Grid.TILE_SIZE
	shape.size = Vector2(width, height)
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.shape = shape
	col_shape.position = Vector2(start_x * Grid.TILE_SIZE + width * 0.5, y * Grid.TILE_SIZE + height * 0.5)
	body.add_child(col_shape)

func terrain_at(pixel_pos: Vector2) -> Dictionary:
	var cell: Vector2i = Grid.pixel_to_tile(pixel_pos)
	if not Grid.is_in_room_bounds(cell):
		return { "name": "void", "medium": "void" }
	if cell.y >= grid.size() or cell.x >= grid[cell.y].length():
		return { "name": "floor" }
	var glyph: String = grid[cell.y][cell.x]
	var def: Dictionary = _tiles_def.get(glyph, {})
	var result: Dictionary = def.duplicate()
	if not result.has("name"):
		result["name"] = "floor"
	return result

func get_exit_at(pixel_pos: Vector2) -> String:
	var cell: Vector2i = Grid.pixel_to_tile(pixel_pos)
	if cell.x <= 0 and exits.has("w"):
		return exits["w"]
	elif cell.x >= Grid.ROOM_TILES_WIDTH - 1 and exits.has("e"):
		return exits["e"]
	elif cell.y <= 0 and exits.has("n"):
		return exits["n"]
	elif cell.y >= Grid.ROOM_TILES_HEIGHT - 1 and exits.has("s"):
		return exits["s"]
	return ""

func _draw() -> void:
	for y: int in range(grid.size()):
		var row: String = grid[y]
		for x: int in range(row.length()):
			var glyph: String = row[x]
			var rect: Rect2 = Rect2(Vector2(x * Grid.TILE_SIZE, y * Grid.TILE_SIZE), Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE))
			var col: Color = Color(0.12, 0.1, 0.08)
			if glyph == "#":
				col = Color(0.3, 0.25, 0.2)
			elif glyph == ":":
				col = Color(0.15, 0.25, 0.35)
			elif glyph == "~":
				col = Color(0.1, 0.35, 0.4)
			elif glyph == "o":
				col = Color(0.04, 0.04, 0.04)
			elif glyph == "^":
				col = Color(0.5, 0.2, 0.2)
			elif glyph == ",":
				col = Color(0.2, 0.22, 0.15)
			draw_rect(rect, col)
