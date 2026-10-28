class_name CombatSystem
extends RefCounted

## CombatSystem: handles System 7 in World._physics_process.
## Evaluates active projectile steps, contact overlaps, death/crash resolution,
## scrap pickups, and hit-stop/screen-shake hooks.

func step(world: Node2D, _tick: int, delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return

	# 1. Step projectiles (if managed via world.projectiles)
	var active_projectiles: Array = world.get("projectiles") if world.get("projectiles") is Array else []
	var projs_to_remove: Array[Projectile] = []
	for p_node: Variant in active_projectiles:
		if not is_instance_valid(p_node):
			continue
		if p_node is Projectile:
			var proj: Projectile = p_node as Projectile
			if proj.is_active:
				proj.step(delta)
			else:
				projs_to_remove.append(proj)
		else:
			projs_to_remove.append(p_node as Projectile)

	for p_rem: Projectile in projs_to_remove:
		active_projectiles.erase(p_rem)

	# 2. Check all machines for 0 integrity / death / crash
	var machines: Array = world.get("machines") if world.get("machines") is Array else []
	var destroyed_hostiles: Array[Machine] = []

	for m_node: Variant in machines:
		if not is_instance_valid(m_node):
			continue
		if not (m_node is Machine):
			continue
		var m: Machine = m_node as Machine
		if m.state == null:
			continue

		# Check 0 integrity or crash
		if m.state.current_integrity <= 0 or m.state.is_crashed:
			var faction: String = m.get_faction()
			if faction == "hostile" or m.is_immune_unit:
				destroyed_hostiles.append(m)
			else:
				# Player or parked host remains in room as Crashed (§1.2.8)
				if not m.state.is_crashed:
					m.state.is_crashed = true
					m.state.crashed.emit()
				# If player was piloting it, force eject to cursor
				var player_m: Machine = world.get("player_machine") as Machine
				if player_m == m:
					var hijack_fsm: Object = world.get("hijack_fsm")
					if hijack_fsm != null and hijack_fsm.has_method("eject_to_cursor"):
						hijack_fsm.call("eject_to_cursor")

	# 3. Process destroyed hostiles: spawn scrap, emit event, queue_free
	for enemy: Machine in destroyed_hostiles:
		_process_enemy_death(world, enemy)

func _process_enemy_death(world: Node2D, enemy: Machine) -> void:
	var enemy_pos: Vector2 = enemy.global_position
	var enemy_id: String = enemy.enemy_id if enemy.enemy_id != "" else enemy.entity_id

	# Spawn scrap pickups
	var drop_range: Array = enemy.enemy_data.get("drops", {}).get("scrap", [1, 2])
	var min_scrap: int = int(drop_range[0]) if drop_range.size() > 0 else 1
	var max_scrap: int = int(drop_range[1]) if drop_range.size() > 1 else min_scrap

	var rng_streams: RngStreams = world.get("rng_streams") as RngStreams
	var scrap_count: int = min_scrap
	if rng_streams != null:
		var stream: RandomNumberGenerator = rng_streams.get_stream("combat")
		scrap_count = stream.randi_range(min_scrap, max_scrap)
	else:
		scrap_count = randi_range(min_scrap, max_scrap)

	var entities_node: Node = world.get_node_or_null("Entities")
	if entities_node != null and scrap_count > 0:
		for i: int in range(scrap_count):
			var pickup: ScrapPickup = ScrapPickup.new()
			pickup.amount = 1
			var angle: float = (TAU / float(scrap_count)) * float(i)
			var spread_speed: float = randf_range(20.0, 50.0)
			pickup.velocity = Vector2.RIGHT.rotated(angle) * spread_speed
			pickup.position = enemy_pos
			entities_node.add_child(pickup)

	# Emit Events.enemy_killed if Events exists
	var tree: SceneTree = world.get_tree()
	if tree != null:
		var root: Window = tree.root
		var events_node: Node = root.get_node_or_null("Events")
		if events_node != null and events_node.has_signal("enemy_killed"):
			events_node.emit_signal("enemy_killed", enemy_id, enemy_pos)

	# Record in world.defeated_enemies_in_room if supported
	var def_arr: Variant = world.get("defeated_enemies_in_room")
	if def_arr is Array and not (def_arr as Array).has(enemy_id):
		(def_arr as Array).append(enemy_id)

	# Unregister and remove
	if world.has_method("unregister_machine"):
		world.call("unregister_machine", enemy)
	enemy.queue_free()
