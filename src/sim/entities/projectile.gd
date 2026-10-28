class_name Projectile
extends Area2D

var source_machine: Machine = null
var source_faction: String = ""
var velocity: Vector2 = Vector2.ZERO
var max_distance: float = 128.0
var distance_traveled: float = 0.0
var damage: int = 1
var damage_type: String = "kinetic"
var status_on_hit: String = ""
var status_duration_ticks: int = 0
var knockback_force: float = 1.0
var proj_color: Color = Color(0.2, 0.9, 1.0)
var radius: float = 2.5
var is_active: bool = true
var seeking_target: Node2D = null
var seek_turn_rate: float = 0.0

func _ready() -> void:
	# Layer 9: projectile (256)
	collision_layer = 1 << (9 - 1)
	# Layer 1: solid (1) and Layer 6: hurtbox (32)
	collision_mask = (1 << (1 - 1)) | (1 << (6 - 1))
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if get_node_or_null("CollisionShape2D") == null:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var circle_shape: CircleShape2D = CircleShape2D.new()
		circle_shape.radius = radius
		shape_node.shape = circle_shape
		add_child(shape_node)

func setup(source: Machine, dir: Vector2, speed_px: float, max_dist_px: float, dmg: int, dmg_type: String = "kinetic") -> void:
	source_machine = source
	if source != null:
		source_faction = source.get_faction()
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	velocity = norm_dir * speed_px
	max_distance = max_dist_px
	damage = dmg
	damage_type = dmg_type
	position = source.global_position + norm_dir * 8.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, proj_color)

func step(delta: float) -> void:
	if not is_active:
		return
	if seeking_target != null and is_instance_valid(seeking_target) and seek_turn_rate > 0.0:
		var target_pos: Vector2 = seeking_target.global_position
		var desired_dir: Vector2 = (target_pos - position).normalized()
		var cur_speed: float = velocity.length()
		var cur_dir: Vector2 = velocity.normalized()
		var new_dir: Vector2 = cur_dir.lerp(desired_dir, clampf(seek_turn_rate * delta, 0.0, 1.0)).normalized()
		velocity = new_dir * cur_speed

	var move_step: Vector2 = velocity * delta
	position += move_step
	distance_traveled += move_step.length()
	queue_redraw()
	
	_check_direct_hits()
	
	if distance_traveled >= max_distance:
		is_active = false
		queue_free()

func _check_direct_hits() -> void:
	if not is_active:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for child: Node in parent_node.get_children():
		if not is_instance_valid(child) or child == source_machine:
			continue
		if child is Switch:
			var sw: Switch = child as Switch
			if global_position.distance_to(sw.global_position) <= 12.0:
				sw.trigger()
				is_active = false
				queue_free()
				return
		if child is Machine:
			var m: Machine = child as Machine
			var hit_dist: float = 10.0
			if m.collider != null and m.collider.shape != null:
				hit_dist = m.collider.shape.get_rect().size.x * 0.5 + radius + 2.0
			if global_position.distance_to(m.global_position) <= hit_dist:
				_apply_hit(m)
				return

func _apply_hit(target_machine: Machine) -> void:
	if not is_active or not is_instance_valid(target_machine):
		return
	if source_faction != "":
		var target_faction: String = target_machine.get_faction()
		if source_faction == target_faction and (source_faction == "hostile" or source_faction == "player"):
			return
	is_active = false
	var impact_dir: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
	target_machine.take_damage(damage, damage_type, false, impact_dir)
	if not status_on_hit.is_empty():
		target_machine.apply_status(status_on_hit, status_duration_ticks)
	var kb_vec: Vector2 = CombatMath.calculate_knockback(impact_dir, knockback_force * float(Grid.TILE_SIZE), target_machine.weight, target_machine.passives)
	target_machine.apply_knockback(kb_vec)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not is_active or not is_instance_valid(area):
		return
	if area is Switch:
		(area as Switch).trigger()
		is_active = false
		queue_free()
		return
	var target_machine: Machine = null
	if is_instance_valid(area.owner) and area.owner is Machine:
		target_machine = area.owner as Machine
	elif is_instance_valid(area.get_parent()) and area.get_parent() is Machine:
		target_machine = area.get_parent() as Machine
		
	if target_machine != null and target_machine != source_machine:
		_apply_hit(target_machine)

func _on_body_entered(body: Node2D) -> void:
	if not is_active or not is_instance_valid(body) or body == source_machine:
		return
	is_active = false
	queue_free()
