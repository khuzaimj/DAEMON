class_name UtilityAbilities
extends RefCounted

static func start_ping(machine: Machine, data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var radius_px: float = float(params.get("radius", 80.0))
	var duration_sec: float = float(params.get("duration", 3.0))
	var ticks: int = AbilityMath.seconds_to_ticks(duration_sec)
	machine.state.apply_status("ping_active", ticks)
	
	var events_node: Node = machine.get_node_or_null("/root/Events")
	if events_node != null and events_node.has_signal("ping_activated"):
		events_node.emit_signal("ping_activated", machine.global_position, radius_px)

static func start_lift_carry(machine: Machine, _data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	if machine.carried_object != null and is_instance_valid(machine.carried_object):
		# Throw carried object
		var obj: CharacterBody2D = machine.carried_object
		obj.set("is_carried", false)
		obj.set("carrier", null)
		obj.velocity = machine.facing * 160.0
		machine.carried_object = null
	else:
		# Search for liftable crate or small machine in front
		var target_pos: Vector2 = machine.global_position + machine.facing * 16.0
		var container: Node = machine.get_parent()
		if container == null:
			return
		for child: Node in container.get_children():
			if child == machine:
				continue
			if child is Crate or child is Machine:
				var body_node: CharacterBody2D = child as CharacterBody2D
				var w: int = int(body_node.get("weight"))
				if w <= 2 and body_node.global_position.distance_to(target_pos) <= 24.0:
					body_node.set("is_carried", true)
					body_node.set("carrier", machine)
					machine.carried_object = body_node
					break

static func start_tow(machine: Machine, _data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	if machine.carried_object != null and is_instance_valid(machine.carried_object):
		var obj: CharacterBody2D = machine.carried_object
		obj.set("is_carried", false)
		obj.set("carrier", null)
		machine.carried_object = null
	else:
		var target_pos: Vector2 = machine.global_position + machine.facing * 16.0
		var container: Node = machine.get_parent()
		if container == null:
			return
		for child: Node in container.get_children():
			if child == machine:
				continue
			if child is Crate or child is Machine:
				var body_node: CharacterBody2D = child as CharacterBody2D
				var w: int = int(body_node.get("weight"))
				if w <= 1 and body_node.global_position.distance_to(target_pos) <= 24.0:
					body_node.set("is_carried", true)
					body_node.set("carrier", machine)
					machine.carried_object = body_node
					break

static func start_bubble_shield(machine: Machine, data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var duration_sec: float = float(params.get("duration", 1.0))
	var ticks: int = AbilityMath.seconds_to_ticks(duration_sec)
	machine.state.invulnerability_ticks = maxi(machine.state.invulnerability_ticks, ticks)
	machine.state.apply_status("bubble_shield", ticks)

static func start_patch(machine: Machine, data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var heal_amt: int = int(params.get("heal", 2))
	machine.heal(heal_amt)
