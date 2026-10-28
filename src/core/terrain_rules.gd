class_name TerrainRules
extends RefCounted

const DEFAULT_RULES: Dictionary = {
	"coolant_heat_drain_per_s": 15.0,
	"spike_damage": 1,
	"spike_interval_ticks": 30,
	"electric_damage": 1,
	"electric_heat": 10.0,
	"electric_interval_ticks": 30,
	"conveyor_speed_px": 32.0,
	"collapse_delay_ticks": 30
}

static func get_rule_float(rules: Dictionary, key: String, default_val: float) -> float:
	if rules.has(key):
		return float(rules[key])
	return default_val

static func get_rule_int(rules: Dictionary, key: String, default_val: int) -> int:
	if rules.has(key):
		return int(rules[key])
	return default_val

static func calculate_conveyor_push(glyph: String, tiles_def: Dictionary, speed_px: float) -> Vector2:
	if not tiles_def.has(glyph):
		return Vector2.ZERO
	var entry: Dictionary = tiles_def[glyph] as Dictionary
	if not entry.has("push"):
		return Vector2.ZERO
	var push: Array = entry["push"] as Array
	if push.size() < 2:
		return Vector2.ZERO
	return Vector2(float(push[0]), float(push[1])).normalized() * speed_px

static func should_ignore_conveyor(mediums: Array) -> bool:
	return mediums.has("hover")

static func is_insulated(passives: Array, body_id: String) -> bool:
	return passives.has("insulated") or body_id == "crawler"

static func can_traverse_magnetic(passives: Array, has_status_cling: bool, _body_id: String) -> bool:
	return has_status_cling or passives.has("cling")

static func can_safely_cross_collapsing(passives: Array, mediums: Array, body_id: String) -> bool:
	return passives.has("collapse_cross") or mediums.has("hover") or body_id == "courier" or body_id == "drone"

static func get_connected_collapse_region(grid: Array[String], start_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid.is_empty():
		return result
	if start_cell.y < 0 or start_cell.y >= grid.size():
		return result
	if start_cell.x < 0 or start_cell.x >= grid[start_cell.y].length():
		return result
	if grid[start_cell.y][start_cell.x] != "-":
		return result

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_cell]
	visited[start_cell] = true

	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		result.append(cur)

		for d: Vector2i in dirs:
			var nb: Vector2i = cur + d
			if nb.y >= 0 and nb.y < grid.size() and nb.x >= 0 and nb.x < grid[nb.y].length():
				if grid[nb.y][nb.x] == "-" and not visited.has(nb):
					visited[nb] = true
					queue.append(nb)

	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return result
