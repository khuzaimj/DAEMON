class_name RoutineController
extends Controller

var parked_state: ParkedState = ParkedState.new()
var heal_tick_counter: int = 0

func _init(p_state: ParkedState = null) -> void:
	if p_state != null:
		parked_state = p_state

func decide(machine: Machine, _tick: int) -> Intent:
	var intent: Intent = Intent.new()
	if machine == null or not is_instance_valid(machine):
		return intent

	match parked_state.routine.to_lower():
		"hold":
			intent.move = Vector2.ZERO
			intent.primary = false
			intent.aim = parked_state.locked_facing

		"repeat":
			intent.move = Vector2.ZERO
			intent.primary = true
			intent.aim = parked_state.locked_facing
			_check_medic_repeat_heal(machine)

		"guard":
			intent.move = Vector2.ZERO
			var hostile: Machine = _find_nearest_hostile_in_range(machine, 80.0)
			if hostile != null:
				var dir: Vector2 = (hostile.position - machine.position).normalized()
				intent.aim = dir
				intent.primary = true
			else:
				intent.aim = parked_state.locked_facing
				intent.primary = false

		"patrol":
			# Walk towards current patrol target
			var target_pos: Vector2 = parked_state.get_current_patrol_target()
			var diff: Vector2 = target_pos - machine.position
			if diff.length() > 3.0:
				intent.move = diff.normalized()
				intent.aim = intent.move
			else:
				intent.move = Vector2.ZERO
				parked_state.check_patrol_arrival(machine.position)

			# Guard while patrolling
			var hostile: Machine = _find_nearest_hostile_in_range(machine, 80.0)
			if hostile != null:
				var dir: Vector2 = (hostile.position - machine.position).normalized()
				intent.aim = dir
				intent.primary = true

		_:
			intent.move = Vector2.ZERO

	return intent

func _find_nearest_hostile_in_range(self_m: Machine, range_px: float) -> Machine:
	var world: Node = self_m.get_parent()
	while world != null and not (world is World):
		world = world.get_parent()
	if world == null:
		return null
	var world_node: World = world as World

	var best_m: Machine = null
	var best_dist: float = range_px
	for m: Machine in world_node.machines:
		if not is_instance_valid(m) or m == self_m:
			continue
		if m.operational_state == "hostile":
			var d: float = self_m.position.distance_to(m.position)
			if d <= best_dist:
				if world_node.check_line_of_sight(self_m.position, m.position):
					best_dist = d
					best_m = m
	return best_m

func _check_medic_repeat_heal(self_m: Machine) -> void:
	if not self_m.passives.has("repeat_heal") and self_m.body_id != "medic":
		return
	heal_tick_counter += 1
	if heal_tick_counter >= 60: # 1.0s interval
		heal_tick_counter = 0
		var world: Node = self_m.get_parent()
		while world != null and not (world is World):
			world = world.get_parent()
		if world == null:
			return
		var world_node: World = world as World
		for m: Machine in world_node.machines:
			if not is_instance_valid(m) or m == self_m:
				continue
			if m.operational_state == "parked" and self_m.position.distance_to(m.position) <= 48.0:
				if m.state != null and m.state.current_integrity < m.state.max_integrity:
					m.heal(2)
