class_name Bridge
extends Node2D

signal bridge_state_changed(bridge_id: String, is_active: bool)

@export var entity_id: String = "bridge_01"
@export var is_active: bool = false
@export var bridge_size: Vector2 = Vector2(16, 16)

var visual_rect: ColorRect = null
var trigger_area: Area2D = null

func _ready() -> void:
	add_to_group("bridges")

	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.size = bridge_size
		rect.position = -bridge_size * 0.5
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	trigger_area = get_node_or_null("Area2D") as Area2D
	if trigger_area == null:
		var area: Area2D = Area2D.new()
		area.name = "Area2D"
		# Layer 7: trigger (64)
		area.collision_layer = 1 << 6
		# Monitor Layer 3: machines (4)
		area.collision_mask = 1 << 2
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = bridge_size
		col.shape = shape
		area.add_child(col)
		add_child(area)
		trigger_area = area

	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)
	set_active(is_active)

func set_active(active: bool) -> void:
	is_active = active
	if visual_rect != null:
		if is_active:
			visual_rect.color = Color(0.45, 0.40, 0.35, 0.9) # Extended metal bridge
			visual_rect.visible = true
		else:
			visual_rect.color = Color(0.2, 0.2, 0.2, 0.2) # Retracted bridge
			visual_rect.visible = false

	if trigger_area != null:
		for b: Node2D in trigger_area.get_overlapping_bodies():
			if b is Machine:
				_update_machine_pit_mask(b as Machine)

	var world_node: World = _find_world()
	if world_node != null:
		for m: Machine in world_node.machines:
			if is_instance_valid(m) and is_point_on_active_bridge(m.global_position):
				_update_machine_pit_mask(m)

	bridge_state_changed.emit(entity_id, is_active)

func _find_world() -> World:
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	return n as World

func _on_body_entered(body: Node2D) -> void:
	if body is Machine:
		_update_machine_pit_mask(body as Machine)

func _on_body_exited(body: Node2D) -> void:
	if body is Machine:
		var m: Machine = body as Machine
		if not m.mediums.has("hover"):
			m.collision_mask |= (1 << (10 - 1)) # Restore pit mask (Layer 10)

func _update_machine_pit_mask(m: Machine) -> void:
	if is_active:
		m.collision_mask &= ~(1 << (10 - 1)) # Clear pit mask while on active bridge
	elif not m.mediums.has("hover"):
		m.collision_mask |= (1 << (10 - 1)) # Block pit

func is_point_on_active_bridge(pixel_pos: Vector2) -> bool:
	if not is_active:
		return false
	var half_size: Vector2 = bridge_size * 0.5
	var r: Rect2 = Rect2(global_position - half_size, bridge_size)
	return r.has_point(pixel_pos)
