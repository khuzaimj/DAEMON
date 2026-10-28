class_name Door
extends StaticBody2D

signal door_state_changed(door_id: String, is_open: bool)

@export var entity_id: String = "door_01"
@export var is_open: bool = false
@export var clearance_level: int = 0
@export var is_energized: bool = false

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
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	_update_visual()
	set_open(is_open)

func set_energized(energized: bool, player_clearance: int) -> void:
	is_energized = energized
	var can_open: bool = is_energized and (player_clearance >= clearance_level)
	set_open(can_open)

func set_open(open_state: bool) -> void:
	var changed: bool = (is_open != open_state)
	is_open = open_state
	if collider != null:
		collider.disabled = is_open
	_update_visual()

	if changed:
		if is_inside_tree():
			var tree: SceneTree = get_tree()
			if tree != null:
				var events_node: Node = tree.root.get_node_or_null("Events")
				if events_node != null:
					events_node.emit_signal("door_changed", entity_id, is_open)
		door_state_changed.emit(entity_id, is_open)

func _update_visual() -> void:
	if visual_rect == null:
		return
	if is_open:
		visual_rect.color = Color(0.1, 0.6, 0.3, 0.25) # Translucent open green
		return

	# Closed door color depends on clearance level
	match clearance_level:
		1:
			visual_rect.color = Color(0.85, 0.55, 0.1, 1.0) # Amber L1
		2:
			visual_rect.color = Color(0.1, 0.75, 0.9, 1.0) # Cyan L2
		3:
			visual_rect.color = Color(0.75, 0.2, 0.9, 1.0) # Neon Violet L3
		4:
			visual_rect.color = Color(0.95, 0.95, 0.95, 1.0) # Pure White L4
		_:
			visual_rect.color = Color(0.3, 0.4, 0.5, 1.0) # Steel blue-grey L0
