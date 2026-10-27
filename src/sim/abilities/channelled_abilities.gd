class_name ChannelledAbilities
extends RefCounted

static func _find_world(machine: Machine) -> World:
	if machine == null:
		return null
	var node: Node = machine.get_parent()
	while node != null:
		if node is World:
			return node as World
		node = node.get_parent()
	return null

static func start_flame_cone(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var angle_deg: float = float(params.get("angle", 45.0))
	var range_px: float = float(params.get("range", 32.0))
	var damage: int = int(params.get("damage", 1))
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	var origin: Vector2 = machine.global_position
	
	# 1. Break weld tiles in cone
	if machine.current_room != null:
		_break_weld_tiles_in_cone(machine.current_room, origin, norm_dir, angle_deg, range_px)
		
	# 2. Damage and apply burn to machines in cone
	var world_node: World = _find_world(machine)
	if world_node != null:
		for target: Machine in world_node.machines:
			if target == machine or not is_instance_valid(target):
				continue
			if AbilityMath.is_point_in_cone(origin, norm_dir, target.global_position, angle_deg, range_px):
				target.take_damage(damage, "thermal")
				target.apply_status("burn", 60) # 1.0s burn

static func start_beam_channel(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var range_px: float = float(params.get("range", 64.0))
	var damage: int = int(params.get("damage", 2))
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	var origin: Vector2 = machine.global_position
	
	# Ray check along beam line to break weld tiles
	if machine.current_room != null:
		var step_dist: float = 8.0
		var steps: int = int(range_px / step_dist)
		for i: int in range(1, steps + 1):
			var sample_pt: Vector2 = origin + norm_dir * (float(i) * step_dist)
			if machine.current_room.break_tile_at(sample_pt, "torch"):
				break # Broken first barrier in line
				
	# Damage machines along beam line
	var world_node: World = _find_world(machine)
	if world_node != null:
		for target: Machine in world_node.machines:
			if target == machine or not is_instance_valid(target):
				continue
			if AbilityMath.is_point_in_cone(origin, norm_dir, target.global_position, 15.0, range_px):
				target.take_damage(damage, "thermal")

static func start_repair_beam(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var range_px: float = float(params.get("range", 48.0))
	var heal_amount: int = int(params.get("heal_amount", 2))
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	var origin: Vector2 = machine.global_position
	
	var world_node: World = _find_world(machine)
	if world_node != null:
		for target: Machine in world_node.machines:
			if target == machine or not is_instance_valid(target):
				continue
			if AbilityMath.is_point_in_cone(origin, norm_dir, target.global_position, 30.0, range_px):
				target.heal(heal_amount)

static func _break_weld_tiles_in_cone(room: RoomRuntime, origin: Vector2, facing: Vector2, angle_deg: float, range_px: float) -> void:
	var min_cell: Vector2i = Grid.pixel_to_tile(origin - Vector2(range_px, range_px))
	var max_cell: Vector2i = Grid.pixel_to_tile(origin + Vector2(range_px, range_px))
	var min_x: int = clampi(min_cell.x, 0, Grid.ROOM_TILES_WIDTH - 1)
	var max_x: int = clampi(max_cell.x, 0, Grid.ROOM_TILES_WIDTH - 1)
	var min_y: int = clampi(min_cell.y, 0, Grid.ROOM_TILES_HEIGHT - 1)
	var max_y: int = clampi(max_cell.y, 0, Grid.ROOM_TILES_HEIGHT - 1)
	
	var broken_any: bool = false
	for cy: int in range(min_y, max_y + 1):
		for cx: int in range(min_x, max_x + 1):
			var cell_pos: Vector2 = Grid.tile_to_pixel_center(Vector2i(cx, cy))
			if AbilityMath.is_point_in_cone(origin, facing, cell_pos, angle_deg, range_px):
				var cell: Vector2i = Vector2i(cx, cy)
				var glyph: String = room.grid[cy][cx]
				var def: Dictionary = room._tiles_def.get(glyph, {})
				if str(def.get("break_by", "")) == "torch":
					room.set_tile_at(cell, ".", false)
					broken_any = true
	if broken_any:
		room._build_collision()
