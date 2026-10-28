class_name PathfindingSystem
extends RefCounted

## Manages room AStarGrid2D instances for different size classes and mediums.
## Built once when a room is loaded (§2.6, §2.15).

var grids: Dictionary = {} # String -> AStarGrid2D
var room_ref: RoomRuntime = null

func setup_room(room: RoomRuntime) -> void:
	room_ref = room
	grids.clear()

	# 1. Ground default (XS, S, M ground bodies)
	var ground_def: AStarGrid2D = _create_base_grid()
	_populate_grid(ground_def, room, "ground", false)
	grids["ground_default"] = ground_def

	# 2. Ground L (24px wide Loader; choke points < 2 tiles marked solid per Guardrail 5)
	var ground_l: AStarGrid2D = _create_base_grid()
	_populate_grid(ground_l, room, "ground", true)
	grids["ground_l"] = ground_l

	# 3. Hover (Drone; pits 'o' are walkable per Guardrail 5)
	var hover_grid: AStarGrid2D = _create_base_grid()
	_populate_grid(hover_grid, room, "hover", false)
	grids["hover"] = hover_grid

	# 4. Liquid (Diver; coolant '~' is walkable)
	var liquid_grid: AStarGrid2D = _create_base_grid()
	_populate_grid(liquid_grid, room, "liquid", false)
	grids["liquid"] = liquid_grid

func _create_base_grid() -> AStarGrid2D:
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 30, 15)
	grid.cell_size = Vector2i(Grid.TILE_SIZE, Grid.TILE_SIZE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	grid.update()
	return grid

func _populate_grid(grid: AStarGrid2D, room: RoomRuntime, medium_mode: String, enforce_large_size: bool) -> void:
	if room == null or room.grid.is_empty():
		return

	# First pass: standard solid glyphs
	for y: int in range(mini(15, room.grid.size())):
		var row: String = room.grid[y]
		for x: int in range(mini(30, row.length())):
			var glyph: String = row[x]
			var is_solid: bool = false

			# Hard walls / solids
			if glyph == "#" or glyph == "X" or glyph == "%":
				is_solid = true
			elif glyph == ":" and medium_mode != "xs":
				# Conduits block non-XS
				is_solid = true
			elif glyph == "o" and medium_mode != "hover":
				# Pits block non-hovering bodies
				is_solid = true

			grid.set_point_solid(Vector2i(x, y), is_solid)

	# Second pass: for large bodies (L size / 24px wide), mark 1-tile choke points as solid
	if enforce_large_size:
		var cells_to_block: Array[Vector2i] = []
		for y: int in range(15):
			for x: int in range(30):
				var pos: Vector2i = Vector2i(x, y)
				if grid.is_point_solid(pos):
					continue

				# Check horizontal pinch (walls North and South)
				var n_solid: bool = (y == 0 or grid.is_point_solid(Vector2i(x, y - 1)))
				var s_solid: bool = (y == 14 or grid.is_point_solid(Vector2i(x, y + 1)))
				if n_solid and s_solid:
					cells_to_block.append(pos)
					continue

				# Check vertical pinch (walls West and East)
				var w_solid: bool = (x == 0 or grid.is_point_solid(Vector2i(x - 1, y)))
				var e_solid: bool = (x == 29 or grid.is_point_solid(Vector2i(x + 1, y)))
				if w_solid and e_solid:
					cells_to_block.append(pos)

		for pos: Vector2i in cells_to_block:
			grid.set_point_solid(pos, true)

func find_path(from_pos: Vector2, to_pos: Vector2, size_class: String = "m", mediums: Array[String] = ["ground"]) -> PackedVector2Array:
	var grid_key: String = "ground_default"
	if mediums.has("hover"):
		grid_key = "hover"
	elif size_class.to_lower() == "l":
		grid_key = "ground_l"
	elif mediums.has("liquid"):
		grid_key = "liquid"

	if not grids.has(grid_key):
		grid_key = "ground_default"
	if not grids.has(grid_key):
		return PackedVector2Array()

	var grid: AStarGrid2D = grids[grid_key] as AStarGrid2D
	var start_cell: Vector2i = Vector2i(clampi(int(from_pos.x) / Grid.TILE_SIZE, 0, 29), clampi(int(from_pos.y) / Grid.TILE_SIZE, 0, 14))
	var end_cell: Vector2i = Vector2i(clampi(int(to_pos.x) / Grid.TILE_SIZE, 0, 29), clampi(int(to_pos.y) / Grid.TILE_SIZE, 0, 14))

	if grid.is_point_solid(start_cell):
		start_cell = _find_nearest_walkable_neighbor(grid, start_cell)
	if grid.is_point_solid(end_cell):
		end_cell = _find_nearest_walkable_neighbor(grid, end_cell)

	var id_path: Array[Vector2i] = grid.get_id_path(start_cell, end_cell)
	var world_path: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in id_path:
		var center: Vector2 = Vector2(float(cell.x) * 16.0 + 8.0, float(cell.y) * 16.0 + 8.0)
		world_path.append(center)

	return world_path

func _find_nearest_walkable_neighbor(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off: Vector2i in offsets:
		var neighbor: Vector2i = cell + off
		if neighbor.x >= 0 and neighbor.x < 30 and neighbor.y >= 0 and neighbor.y < 15:
			if not grid.is_point_solid(neighbor):
				return neighbor
	return cell
