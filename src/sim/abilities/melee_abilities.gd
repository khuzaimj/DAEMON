class_name MeleeAbilities
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

static func start_melee_arc(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var arc_deg: float = float(params.get("arc", 90.0))
	var radius_px: float = float(params.get("radius", 24.0))
	var damage: int = int(params.get("damage", 2))
	var knockback: float = float(params.get("knockback", 3.0))
	var clears_verb: String = str(params.get("clears", "sweep"))
	
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	var origin: Vector2 = machine.global_position
	
	# 1. Clear tiles in RoomRuntime (e.g. grime clear_by: "sweep")
	if machine.current_room != null and machine.current_room.has_method("clear_tiles_in_arc"):
		machine.current_room.call("clear_tiles_in_arc", origin, norm_dir, arc_deg, radius_px, clears_verb)
		
	# 2. Hit targets in arc (other machines)
	var world_node: World = _find_world(machine)
	if world_node != null:
		for target: Machine in world_node.machines:
			if target == machine or not is_instance_valid(target):
				continue
			if AbilityMath.is_point_in_arc(origin, norm_dir, target.global_position, arc_deg, radius_px):
				target.take_damage(damage, "kinetic")
				var kb_vec: Vector2 = AbilityMath.calculate_knockback(origin, target.global_position, knockback * float(Grid.TILE_SIZE))
				target.velocity += kb_vec

static func start_claw(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var arc_deg: float = float(params.get("arc", 60.0))
	var radius_px: float = float(params.get("radius", 18.0))
	var damage: int = int(params.get("damage", 2))
	var knockback: float = float(params.get("knockback", 1.5))
	
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	var origin: Vector2 = machine.global_position
	
	var world_node: World = _find_world(machine)
	if world_node != null:
		for target: Machine in world_node.machines:
			if target == machine or not is_instance_valid(target):
				continue
			if AbilityMath.is_point_in_arc(origin, norm_dir, target.global_position, arc_deg, radius_px):
				target.take_damage(damage, "kinetic")
				var kb_vec: Vector2 = AbilityMath.calculate_knockback(origin, target.global_position, knockback * float(Grid.TILE_SIZE))
				target.velocity += kb_vec

static func start_suction(machine: Machine, data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var radius_px: float = float(params.get("radius", 64.0))
	var pull_speed: float = float(params.get("pull_speed", 120.0))
	var origin: Vector2 = machine.global_position
	
	var world_node: World = _find_world(machine)
	if world_node != null:
		for target: Machine in world_node.machines:
			if target == machine or not is_instance_valid(target):
				continue
			var dist: float = origin.distance_to(target.global_position)
			if dist <= radius_px and dist > 4.0:
				var pull_dir: Vector2 = (origin - target.global_position).normalized()
				# Pull lighter entities toward machine
				if target.weight <= machine.weight:
					target.position += pull_dir * (pull_speed * (1.0 / 60.0))
