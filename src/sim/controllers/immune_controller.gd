class_name ImmuneController
extends Controller

## ImmuneController: Drives non-hijackable immune system entities
## (glitch_mite, antivirus_sentinel, quarantine_pod, garbage_collector)

var immune_type: String = "glitch_mite"
var trapped_machines: Array[Machine] = []
var shoot_timer: int = 0
var patrol_dir: int = 1

func _init(p_type: String = "glitch_mite") -> void:
	immune_type = p_type

func _get_world(m: Machine) -> World:
	if m == null or not is_instance_valid(m):
		return null
	var node: Node = m.get_parent()
	while node != null and is_instance_valid(node) and not (node is World):
		node = node.get_parent()
	if node != null and is_instance_valid(node) and node is World:
		return node as World
	return null

func release_trapped_hosts() -> void:
	for m: Machine in trapped_machines:
		if is_instance_valid(m):
			m.set_meta("quarantined", false)
	trapped_machines.clear()

func decide(machine: Machine, tick: int) -> Intent:
	var intent: Intent = Intent.new()
	if machine == null or not is_instance_valid(machine):
		return intent

	var world: World = _get_world(machine)
	if world == null:
		return intent

	match immune_type:
		"glitch_mite":
			_step_glitch_mite(machine, world, tick, intent)
		"antivirus_sentinel":
			_step_antivirus_sentinel(machine, world, tick, intent)
		"quarantine_pod":
			_step_quarantine_pod(machine, world, tick, intent)
		"garbage_collector":
			_step_garbage_collector(machine, world, tick, intent)

	return intent

func _step_glitch_mite(machine: Machine, world: World, tick: int, intent: Intent) -> void:
	var target: Machine = world.player_machine
	if target == null or not is_instance_valid(target):
		# Look for nearest parked machine
		var best_dist: float = 9999.0
		for m: Machine in world.machines:
			if is_instance_valid(m) and m != machine and m.operational_state == "parked":
				var d: float = machine.global_position.distance_to(m.global_position)
				if d < best_dist:
					best_dist = d
					target = m

	if target != null and is_instance_valid(target):
		var dist: float = machine.global_position.distance_to(target.global_position)
		if dist <= 14.0:
			if target.state != null:
				target.state.add_heat(15.0)
			target.take_damage(1, "electric")
			# Self-destruct on contact
			if machine.state != null:
				machine.state.current_integrity = 0
			intent.move = Vector2.ZERO
			return

		var dir: Vector2 = (target.global_position - machine.global_position).normalized()
		var jitter: float = sin(float(tick) * 0.45) * 0.75
		var move_dir: Vector2 = dir.rotated(jitter)
		intent.move = move_dir
		machine.facing = dir
	else:
		intent.move = Vector2.ZERO

func _step_antivirus_sentinel(machine: Machine, world: World, _tick: int, intent: Intent) -> void:
	var is_cursor_exposed: bool = false
	if world.hijack_fsm != null and world.hijack_fsm.state == HijackFSM.State.CURSOR:
		is_cursor_exposed = true
	elif world.player_machine != null and is_instance_valid(world.player_machine) and world.player_machine.body_id == "cursor":
		is_cursor_exposed = true

	if is_cursor_exposed and world.player_machine != null and is_instance_valid(world.player_machine):
		var target_pos: Vector2 = world.player_machine.global_position
		var dir: Vector2 = (target_pos - machine.global_position).normalized()
		intent.move = dir
		machine.facing = dir

		shoot_timer += 1
		if shoot_timer >= 60: # 1.0 second firing cadence
			shoot_timer = 0
			var proj: Projectile = Projectile.new()
			proj.setup(machine, dir, 120.0, 240.0, 2, "electric")
			proj.seeking_target = world.player_machine
			proj.seek_turn_rate = 5.0
			proj.proj_color = Color(1.0, 0.2, 0.3)
			if world.entities_container != null:
				world.entities_container.add_child(proj)
			else:
				world.add_child(proj)
			world.register_projectile(proj)
	else:
		shoot_timer = 0
		intent.move = Vector2.ZERO

func _step_quarantine_pod(machine: Machine, world: World, tick: int, intent: Intent) -> void:
	intent.move = Vector2.ZERO
	if tick % 15 == 0:
		for m: Machine in world.machines:
			if not is_instance_valid(m) or m == machine:
				continue
			if m.operational_state == "parked":
				if machine.global_position.distance_to(m.global_position) <= 80.0:
					if not bool(m.get_meta("quarantined", false)):
						m.set_meta("quarantined", true)
						if not trapped_machines.has(m):
							trapped_machines.append(m)

func _step_garbage_collector(machine: Machine, world: World, _tick: int, intent: Intent) -> void:
	# Check contact with parked hosts and delete them
	var machines_to_delete: Array[Machine] = []
	for m: Machine in world.machines:
		if not is_instance_valid(m) or m == machine:
			continue
		if m.operational_state == "parked":
			if machine.global_position.distance_to(m.global_position) <= 20.0:
				machines_to_delete.append(m)

	for del_m: Machine in machines_to_delete:
		var ent_id: String = del_m.entity_id
		world.machines.erase(del_m)
		del_m.queue_free()
		var events_node: Node = world.get_node_or_null("/root/Events")
		if events_node != null:
			events_node.emit_signal("host_recycled", ent_id, 0)

	# Roam back and forth
	if machine.is_on_wall():
		patrol_dir = -patrol_dir

	intent.move = Vector2(float(patrol_dir), 0.0)
	machine.facing = intent.move
