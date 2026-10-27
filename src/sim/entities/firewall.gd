class_name Firewall
extends StaticBody2D

signal firewall_state_changed(firewall_id: String, is_active: bool)

@export var entity_id: String = "firewall_01"
@export var is_active: bool = true

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("firewalls")
	# Layer 8: firewall (1 << 7 = 128)
	collision_layer = 1 << 7
	collision_mask = 0

	collider = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(16, 16)
		col_node.shape = rect_shape
		col_node.name = "CollisionShape2D"
		add_child(col_node)
		collider = col_node

	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(16, 16)
		rect.position = Vector2(-8, -8)
		rect.color = Color(1.0, 0.4, 0.1, 0.75) # Vibrant orange/amber firewall barrier
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	set_active(is_active)

func set_active(active: bool) -> void:
	is_active = active
	if collider != null:
		collider.disabled = not is_active
	if visual_rect != null:
		if is_active:
			visual_rect.color = Color(1.0, 0.4, 0.1, 0.75)
		else:
			visual_rect.color = Color(0.3, 0.15, 0.05, 0.15) # Dimmed offline

	firewall_state_changed.emit(entity_id, is_active)
