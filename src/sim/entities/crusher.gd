class_name Crusher
extends Area2D

signal crusher_state_changed(crusher_id: String, is_active: bool)

@export var entity_id: String = "crusher_01"
@export var is_active: bool = false
@export var damage: int = 10
@export var crusher_size: Vector2 = Vector2(24, 24)

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("crushers")
	# Layer 7: trigger (64)
	collision_layer = 1 << 6
	# Monitor Layer 3 (machines) and Layer 4 (pushables)
	collision_mask = (1 << 2) | (1 << 3)

	collider = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = crusher_size
		col_node.shape = rect_shape
		col_node.name = "CollisionShape2D"
		add_child(col_node)
		collider = col_node

	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.size = crusher_size
		rect.position = -crusher_size * 0.5
		rect.color = Color(0.6, 0.2, 0.2, 0.4) # Retracted idle
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	set_active(is_active)

func set_active(active: bool) -> void:
	var was_active: bool = is_active
	is_active = active
	if is_active and not was_active:
		slam()
	elif not is_active:
		if visual_rect != null:
			visual_rect.color = Color(0.6, 0.2, 0.2, 0.4)
	crusher_state_changed.emit(entity_id, is_active)

func slam() -> void:
	if visual_rect != null:
		visual_rect.color = Color(0.9, 0.1, 0.1, 0.95) # Crushing active
	for b: Node2D in get_overlapping_bodies():
		if b is Machine:
			var m: Machine = b as Machine
			m.take_damage(damage, "kinetic", false, Vector2.DOWN)
		elif b is Crate:
			var c: Crate = b as Crate
			c.queue_free()
