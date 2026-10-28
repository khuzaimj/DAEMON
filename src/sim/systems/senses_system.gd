class_name SensesSystem
extends RefCounted

## SensesSystem: handles System 1 in World._physics_process (§2.5).
## Evaluates vision cones, hearing radii, line-of-sight raycasts against Layer 1 (solid),
## and broadcasts group alerts to nearby allies.

func step(world: Node2D, tick: int, _delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return

	var machines: Array = world.get("machines") if world.get("machines") is Array else []
	var player_m: Machine = world.get("player_machine") as Machine

	for m_node: Variant in machines:
		if not (m_node is Machine) or not is_instance_valid(m_node):
			continue
		var m: Machine = m_node as Machine
		if not (m.controller is AIController):
			continue
		var ai_ctrl: AIController = m.controller as AIController

		# Target selection for hostile AI: default to player_machine
		var target: Machine = player_m
		if target == null or not is_instance_valid(target) or target.state.is_crashed:
			# Look for any friendly/player-faction machine in room
			target = _find_nearest_opposing_machine(m, machines)

		if target == null or not is_instance_valid(target):
			ai_ctrl.update_senses(null, false, false, tick)
			continue

		var senses_def: Dictionary = m.enemy_data.get("senses", {})
		var vision_tiles: float = float(senses_def.get("vision", 6.0))
		var hearing_tiles: float = float(senses_def.get("hearing", 4.0))
		var fov_deg: float = float(senses_def.get("fov_deg", 100.0))

		var vision_px: float = vision_tiles * float(Grid.TILE_SIZE)
		var hearing_px: float = hearing_tiles * float(Grid.TILE_SIZE)

		var dist_px: float = m.global_position.distance_to(target.global_position)
		var dir_to_target: Vector2 = (target.global_position - m.global_position).normalized()

		# 1. Hearing check (omnidirectional)
		var can_hear: bool = (dist_px <= hearing_px)

		# 2. Vision check (cone FOV + Raycast Line of Sight)
		var can_see: bool = false
		if dist_px <= vision_px:
			var facing_norm: Vector2 = m.facing.normalized() if m.facing != Vector2.ZERO else Vector2.DOWN
			var angle_diff: float = absf(facing_norm.angle_to(dir_to_target))
			if angle_diff <= deg_to_rad(fov_deg * 0.5):
				# Inside vision cone, test line-of-sight against Layer 1 (solid)
				if has_line_of_sight(world, m.global_position, target.global_position):
					can_see = true

		var was_seeing: bool = ai_ctrl.can_see_target
		ai_ctrl.update_senses(target, can_see, can_hear, tick)

		# 3. Group alert broadcast: if enemy just spotted the player, alert nearby allies
		if can_see and not was_seeing:
			_broadcast_group_alert(world, m, target, 8.0 * float(Grid.TILE_SIZE), tick)

func _find_nearest_opposing_machine(source: Machine, machines: Array) -> Machine:
	var my_faction: String = source.get_faction()
	var nearest: Machine = null
	var min_dist: float = 99999.0

	for m_node: Variant in machines:
		if m_node is Machine and is_instance_valid(m_node) and m_node != source:
			var other: Machine = m_node as Machine
			if other.state != null and not other.state.is_crashed:
				var other_fac: String = other.get_faction()
				if (my_faction == "hostile" and other_fac == "player") or (my_faction == "player" and other_fac == "hostile"):
					var d: float = source.global_position.distance_to(other.global_position)
					if d < min_dist:
						min_dist = d
						nearest = other
	return nearest

static func has_line_of_sight(world: Node2D, from_pos: Vector2, to_pos: Vector2) -> bool:
	if not world.is_inside_tree():
		return true
	var space_state: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	# Layer 1: solid (1 << 0 = 1)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

func _broadcast_group_alert(world: Node2D, alerter: Machine, target: Machine, alert_radius_px: float, tick: int) -> void:
	var machines: Array = world.get("machines") if world.get("machines") is Array else []
	var my_faction: String = alerter.get_faction()

	for m_node: Variant in machines:
		if m_node is Machine and is_instance_valid(m_node) and m_node != alerter:
			var ally: Machine = m_node as Machine
			if ally.get_faction() == my_faction and ally.controller is AIController:
				if alerter.global_position.distance_to(ally.global_position) <= alert_radius_px:
					(ally.controller as AIController).receive_alert(target.global_position, target, tick)
