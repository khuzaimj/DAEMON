class_name Door
extends StaticBody2D

signal door_state_changed(door_id: String, is_open: bool)

@export var entity_id: String = "door_01"
@export var is_open: bool = false

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("doors")
	# Layer 1: solid (1)
	collision_layer = 1
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
		rect.color = Color(0.3, 0.4, 0.5, 1.0) # Steel blue-grey door
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	set_open(is_open)

func set_open(open_state: bool) -> void:
	is_open = open_state
	if collider != null:
		collider.disabled = is_open
	if visual_rect != null:
		if is_open:
			visual_rect.color = Color(0.1, 0.6, 0.3, 0.3) # Translucent open green
		else:
			visual_rect.color = Color(0.3, 0.4, 0.5, 1.0) # Solid closed

	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree != null:
			var events_node: Node = tree.root.get_node_or_null("Events")
			if events_node != null:
				events_node.emit_signal("door_changed", entity_id, is_open)

	door_state_changed.emit(entity_id, is_open)
