class_name RoomRuntime
extends Node2D

var room_data: Dictionary = {}
var room_id: String = ""
var exits: Dictionary = {}
var grid: Array[String] = []

var _tiles_def: Dictionary = {}
var _tilemap_layer: TileMapLayer = null
var _static_body_solid: StaticBody2D = null
var _static_body_conduit: StaticBody2D = null
var _static_body_pit: StaticBody2D = null

func setup(data: Dictionary) -> void:
	room_data = data
	room_id = data.get("id", "")
	exits = data.get("exits", {})
	grid.clear()
	var raw_grid: Array = data.get("grid", [])
	for row: Variant in raw_grid:
		grid.append(str(row))
	_load_tiles_def()
	_build_visual_tilemap()
	_build_collision()

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

func _build_visual_tilemap() -> void:
	if _tilemap_layer != null:
		_tilemap_layer.queue_free()

	_tilemap_layer = TileMapLayer.new()
	_tilemap_layer.name = "TileMapLayer"
	add_child(_tilemap_layer)

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(Grid.TILE_SIZE, Grid.TILE_SIZE)

	var glyph_order: Array[String] = [".", "#", ":", "o", "~", "^", ",", "X", "%", "*"]
	var colors: Array[Color] = [
		Color(0.12, 0.10, 0.08), # . floor
		Color(0.30, 0.25, 0.20), # # wall
		Color(0.15, 0.25, 0.35), # : conduit
		Color(0.04, 0.04, 0.04), # o pit
		Color(0.10, 0.35, 0.40), # ~ coolant
		Color(0.50, 0.20, 0.20), # ^ spikes
		Color(0.20, 0.22, 0.15), # , grime
		Color(0.40, 0.35, 0.30), # X cracked wall
		Color(0.55, 0.40, 0.15), # % weld barrier
		Color(0.35, 0.10, 0.30)  # * bitrot
	]

	var img: Image = Image.create(Grid.TILE_SIZE * glyph_order.size(), Grid.TILE_SIZE, false, Image.FORMAT_RGBA8)
	for i: int in range(glyph_order.size()):
		var col: Color = colors[i]
		for py: int in range(Grid.TILE_SIZE):
			for px: int in range(Grid.TILE_SIZE):
				img.set_pixel(i * Grid.TILE_SIZE + px, py, col)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(Grid.TILE_SIZE, Grid.TILE_SIZE)
	for i: int in range(glyph_order.size()):
		source.create_tile(Vector2i(i, 0))
	tile_set.add_source(source, 0)
	_tilemap_layer.tile_set = tile_set

	for y: int in range(grid.size()):
		var row: String = grid[y]
		for x: int in range(row.length()):
			var glyph: String = row[x]
			var idx: int = glyph_order.find(glyph)
			if idx == -1:
				idx = 0
			_tilemap_layer.set_cell(Vector2i(x, y), 0, Vector2i(idx, 0))

func _build_collision() -> void:
	if _static_body_solid != null:
		_static_body_solid.queue_free()
	if _static_body_conduit != null:
		_static_body_conduit.queue_free()
	if _static_body_pit != null:
		_static_body_pit.queue_free()

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

	_static_body_pit = StaticBody2D.new()
	_static_body_pit.name = "CollisionPit"
	_static_body_pit.collision_layer = 1 << (10 - 1) # Layer 10: pit
	_static_body_pit.collision_mask = 0
	add_child(_static_body_pit)

	_generate_merged_runs(_static_body_solid, func(glyph: String) -> bool:
		var def: Dictionary = _tiles_def.get(glyph, {})
		return def.get("solid", false)
	)
	_generate_merged_runs(_static_body_conduit, func(glyph: String) -> bool:
		var def: Dictionary = _tiles_def.get(glyph, {})
		return def.get("fits", "") == "xs"
	)
	_generate_merged_runs(_static_body_pit, func(glyph: String) -> bool:
		var def: Dictionary = _tiles_def.get(glyph, {})
		return def.get("medium", "") == "void"
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

func set_tile_at(cell: Vector2i, new_glyph: String, rebuild_collision: bool = true) -> void:
	if not Grid.is_in_room_bounds(cell):
		return
	if cell.y >= grid.size() or cell.x >= grid[cell.y].length():
		return
	var row: String = grid[cell.y]
	grid[cell.y] = row.substr(0, cell.x) + new_glyph + row.substr(cell.x + 1)
	
	if _tilemap_layer != null:
		var glyph_order: Array[String] = [".", "#", ":", "o", "~", "^", ",", "X", "%", "*"]
		var idx: int = glyph_order.find(new_glyph)
		if idx == -1:
			idx = 0
		_tilemap_layer.set_cell(cell, 0, Vector2i(idx, 0))
		
	if rebuild_collision:
		_build_collision()

func clear_tiles_in_arc(origin: Vector2, facing: Vector2, arc_deg: float, radius: float, verb: String) -> int:
	var cleared_count: int = 0
	var min_cell: Vector2i = Grid.pixel_to_tile(origin - Vector2(radius, radius))
	var max_cell: Vector2i = Grid.pixel_to_tile(origin + Vector2(radius, radius))
	
	var min_x: int = clampi(min_cell.x, 0, Grid.ROOM_TILES_WIDTH - 1)
	var max_x: int = clampi(max_cell.x, 0, Grid.ROOM_TILES_WIDTH - 1)
	var min_y: int = clampi(min_cell.y, 0, Grid.ROOM_TILES_HEIGHT - 1)
	var max_y: int = clampi(max_cell.y, 0, Grid.ROOM_TILES_HEIGHT - 1)
	
	var modified: bool = false
	for cy: int in range(min_y, max_y + 1):
		for cx: int in range(min_x, max_x + 1):
			var cell_pos: Vector2 = Grid.tile_to_pixel_center(Vector2i(cx, cy))
			if AbilityMath.is_point_in_arc(origin, facing, cell_pos, arc_deg, radius):
				var cell: Vector2i = Vector2i(cx, cy)
				var glyph: String = grid[cy][cx]
				var def: Dictionary = _tiles_def.get(glyph, {})
				var clear_by: String = str(def.get("clear_by", ""))
				if clear_by == verb:
					set_tile_at(cell, ".", false)
					cleared_count += 1
					modified = true
	if modified:
		_build_collision()
	return cleared_count

func break_tile_at(pixel_pos: Vector2, verb: String) -> bool:
	var cell: Vector2i = Grid.pixel_to_tile(pixel_pos)
	if not Grid.is_in_room_bounds(cell):
		return false
	if cell.y >= grid.size() or cell.x >= grid[cell.y].length():
		return false
	var glyph: String = grid[cell.y][cell.x]
	var def: Dictionary = _tiles_def.get(glyph, {})
	var break_by: String = str(def.get("break_by", ""))
	if break_by == verb:
		set_tile_at(cell, ".", true)
		return true
	return false

func step_bitrot(world: Node, tick: int) -> void:
	if grid.is_empty() or world == null or not is_instance_valid(world):
		return
	if tick % 60 == 0:
		var machines_val: Variant = world.get("machines")
		if machines_val is Array:
			for m_node: Variant in (machines_val as Array):
				if not is_instance_valid(m_node) or not (m_node is Machine):
					continue
				var m: Machine = m_node as Machine
				if m.state == null or m.state.current_integrity <= 0:
					continue
				if m.body_id == "janitor" or m.passives.has("bitrot_immune") or m.passives.has("immune_bitrot"):
					continue
				var terr: Dictionary = terrain_at(m.position)
				if terr.get("hazard", "") == "bitrot" or terr.get("name", "") == "bitrot":
					m.take_damage(1, "kinetic")

	if tick % 120 == 0:
		_step_bitrot_spread(world)

func _step_bitrot_spread(world: Node) -> void:
	var bitrot_cells: Array[Vector2i] = []
	for y: int in range(grid.size()):
		var row: String = grid[y]
		for x: int in range(row.length()):
			if row[x] == "*":
				bitrot_cells.append(Vector2i(x, y))
	if bitrot_cells.is_empty():
		return

	var rng: RandomNumberGenerator = null
	var rng_streams: Variant = world.get("rng_streams")
	if rng_streams != null and rng_streams is RngStreams:
		rng = (rng_streams as RngStreams).get_stream("combat")
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = 101

	var spread_count: int = mini(2, bitrot_cells.size())
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for i: int in range(spread_count):
		var source_idx: int = rng.randi_range(0, bitrot_cells.size() - 1)
		var src_cell: Vector2i = bitrot_cells[source_idx]
		var dir_idx: int = rng.randi_range(0, dirs.size() - 1)
		var target_cell: Vector2i = src_cell + dirs[dir_idx]
		if Grid.is_in_room_bounds(target_cell) and target_cell.y < grid.size() and target_cell.x < grid[target_cell.y].length():
			var cur_glyph: String = grid[target_cell.y][target_cell.x]
			if cur_glyph == "." or cur_glyph == ",":
				set_tile_at(target_cell, "*", false)
