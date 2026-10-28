class_name AIController
extends Controller

signal group_alert_raised(alert_pos: Vector2, target: Machine)

var ai_id: String = ""
var current_state: String = "patrol"
var state_ticks: int = 0
var fsm_params: Dictionary = {}
var states: Dictionary = {}

var target: Machine = null
var can_see_target: bool = false
var can_hear_target: bool = false
var last_seen_pos: Vector2 = Vector2.ZERO
var last_seen_tick: int = -9999

var patrol_waypoints: Array[Vector2] = []
var patrol_index: int = 0
var patrol_dir: int = 1

var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var path_recalc_cooldown: int = 0

func setup(preset: Dictionary) -> void:
	ai_id = str(preset.get("id", ""))
	current_state = str(preset.get("initial", "patrol"))
	fsm_params = preset.get("params", {})
	states = preset.get("states", {})
	state_ticks = 0

func update_senses(p_target: Machine, see: bool, hear: bool, tick: int) -> void:
	target = p_target
	can_see_target = see
	can_hear_target = hear
	if see and p_target != null:
		last_seen_pos = p_target.global_position
		last_seen_tick = tick

func receive_alert(alert_pos: Vector2, p_target: Machine, tick: int) -> void:
	if target == null:
		target = p_target
	last_seen_pos = alert_pos
	last_seen_tick = tick
	if current_state == "patrol" or current_state == "guard":
		_transition_to("chase")

func _transition_to(new_state: String) -> void:
	if current_state != new_state and states.has(new_state):
		current_state = new_state
		state_ticks = 0
		path_index = 0
		current_path.clear()
		path_recalc_cooldown = 0

func decide(machine: Machine, tick: int) -> Intent:
	var intent: Intent = Intent.new()
	if machine == null or not is_instance_valid(machine):
		return intent

	state_ticks += 1
	if path_recalc_cooldown > 0:
		path_recalc_cooldown -= 1

	# 1. Evaluate transitions
	_evaluate_transitions(machine, tick)

	# 2. Execute state action
	var state_def: Dictionary = states.get(current_state, {})
	var do_action: String = str(state_def.get("do", ""))

	match do_action:
		"patrol_waypoints":
			_do_patrol_waypoints(machine, intent)
		"move_to_target":
			_do_move_to_target(machine, intent)
		"use_primary":
			_do_use_primary(machine, intent)
		"use_secondary":
			_do_use_secondary(machine, intent)
		"wander_last_seen":
			_do_wander_last_seen(machine, intent)
		"flee":
			_do_flee(machine, intent)
		"guard":
			_do_guard(machine, intent)
		"heal_ally":
			_do_heal_ally(machine, intent)
		_:
			intent.move = Vector2.ZERO

	return intent

func _evaluate_transitions(machine: Machine, tick: int) -> void:
	var state_def: Dictionary = states.get(current_state, {})
	var transitions: Dictionary = state_def.get("on", {})

	var attack_range_tiles: float = float(fsm_params.get("attack_range", 1.5))
	var attack_range_px: float = attack_range_tiles * 16.0
	var search_time_sec: float = float(fsm_params.get("search_time", 3.0))
	var search_ticks: int = int(search_time_sec * 60.0)

	var dist_to_target: float = 99999.0
	if target != null and is_instance_valid(target):
		dist_to_target = machine.global_position.distance_to(target.global_position)

	for trigger: Variant in transitions.keys():
		var trigger_name: String = str(trigger)
		var next_state: String = str(transitions[trigger])
		var should_transition: bool = false

		match trigger_name:
			"see_target":
				should_transition = can_see_target
			"hear_target":
				should_transition = can_hear_target
			"in_range":
				should_transition = (dist_to_target <= attack_range_px)
			"out_of_range":
				should_transition = (dist_to_target > attack_range_px + 8.0)
			"lost_target":
				should_transition = (not can_see_target and (tick - last_seen_tick) > 60)
			"timeout":
				should_transition = (state_ticks >= search_ticks)
			"ally_damaged":
				should_transition = _has_damaged_ally(machine)

		if should_transition:
			_transition_to(next_state)
			break

func _do_patrol_waypoints(machine: Machine, intent: Intent) -> void:
	if patrol_waypoints.is_empty():
		var p1: Vector2 = machine.global_position
		var p2: Vector2 = p1 + machine.facing * 48.0
		patrol_waypoints = [p1, p2]

	var target_wp: Vector2 = patrol_waypoints[patrol_index]
	var diff: Vector2 = target_wp - machine.global_position
	if diff.length() <= 4.0:
		patrol_index += patrol_dir
		if patrol_index >= patrol_waypoints.size() or patrol_index < 0:
			patrol_dir *= -1
			patrol_index = clampi(patrol_index + patrol_dir, 0, maxi(0, patrol_waypoints.size() - 1))
		target_wp = patrol_waypoints[patrol_index]
		diff = target_wp - machine.global_position

	var move_spd: float = float(fsm_params.get("patrol_speed", 0.6))
	intent.move = diff.normalized() * move_spd
	intent.aim = intent.move

func _do_move_to_target(machine: Machine, intent: Intent) -> void:
	var dest: Vector2 = target.global_position if (target != null and is_instance_valid(target)) else last_seen_pos
	if dest == Vector2.ZERO:
		intent.move = Vector2.ZERO
		return

	# Recompute path if needed
	if current_path.is_empty() or path_index >= current_path.size() or path_recalc_cooldown <= 0:
		var world_node: Node = machine.get_tree().current_scene if machine.is_inside_tree() else null
		if world_node != null and world_node.get("pathfinding_system") != null:
			var pf: PathfindingSystem = world_node.get("pathfinding_system") as PathfindingSystem
			current_path = pf.find_path(machine.global_position, dest, machine.size_class, machine.mediums)
			path_index = 0
			path_recalc_cooldown = 20 # Recompute at most every 20 ticks

	if not current_path.is_empty() and path_index < current_path.size():
		var wp: Vector2 = current_path[path_index]
		var diff: Vector2 = wp - machine.global_position
		if diff.length() <= 6.0:
			path_index += 1
			if path_index < current_path.size():
				wp = current_path[path_index]
				diff = wp - machine.global_position

		var chase_spd: float = float(fsm_params.get("chase_speed", 1.0))
		intent.move = diff.normalized() * chase_spd
	else:
		var direct: Vector2 = dest - machine.global_position
		intent.move = direct.normalized()

	if target != null and is_instance_valid(target):
		intent.aim = (target.global_position - machine.global_position).normalized()
	else:
		intent.aim = intent.move

func _do_use_primary(machine: Machine, intent: Intent) -> void:
	intent.move = Vector2.ZERO
	if target != null and is_instance_valid(target):
		intent.aim = (target.global_position - machine.global_position).normalized()
	intent.primary = true

func _do_use_secondary(machine: Machine, intent: Intent) -> void:
	intent.move = Vector2.ZERO
	if target != null and is_instance_valid(target):
		intent.aim = (target.global_position - machine.global_position).normalized()
	intent.secondary = true

func _do_wander_last_seen(machine: Machine, intent: Intent) -> void:
	var diff: Vector2 = last_seen_pos - machine.global_position
	if diff.length() > 8.0:
		intent.move = diff.normalized() * 0.5
		intent.aim = intent.move
	else:
		intent.move = Vector2.ZERO
		# Slowly scan facing
		var scan_angle: float = float(state_ticks) * 0.05
		intent.aim = Vector2.RIGHT.rotated(scan_angle)

func _do_flee(machine: Machine, intent: Intent) -> void:
	if target != null and is_instance_valid(target):
		var flee_dir: Vector2 = (machine.global_position - target.global_position).normalized()
		intent.move = flee_dir
		intent.aim = flee_dir
	else:
		intent.move = Vector2.ZERO

func _do_guard(machine: Machine, intent: Intent) -> void:
	intent.move = Vector2.ZERO
	if target != null and is_instance_valid(target) and can_see_target:
		intent.aim = (target.global_position - machine.global_position).normalized()
		var attack_range_px: float = float(fsm_params.get("attack_range", 5.0)) * 16.0
		if machine.global_position.distance_to(target.global_position) <= attack_range_px:
			intent.primary = true

func _do_heal_ally(machine: Machine, intent: Intent) -> void:
	var ally: Machine = _find_damaged_ally(machine)
	if ally == null:
		intent.move = Vector2.ZERO
		return

	var dist: float = machine.global_position.distance_to(ally.global_position)
	if dist > 40.0:
		# Approach ally
		var diff: Vector2 = ally.global_position - machine.global_position
		intent.move = diff.normalized()
		intent.aim = intent.move
	else:
		intent.move = Vector2.ZERO
		intent.aim = (ally.global_position - machine.global_position).normalized()
		intent.primary = true

func _has_damaged_ally(machine: Machine) -> bool:
	return _find_damaged_ally(machine) != null

func _find_damaged_ally(machine: Machine) -> Machine:
	var world_node: Node = machine.get_tree().current_scene if machine.is_inside_tree() else null
	if world_node == null:
		return null
	var machines: Array = world_node.get("machines") if world_node.get("machines") is Array else []
	var my_faction: String = machine.get_faction()

	for m_node: Variant in machines:
		if m_node is Machine and is_instance_valid(m_node) and m_node != machine:
			var other: Machine = m_node as Machine
			if other.get_faction() == my_faction and other.state != null:
				if other.state.current_integrity < other.state.max_integrity and not other.state.is_crashed:
					return other
	return null
