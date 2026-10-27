class_name InfraNode
extends Area2D

signal node_piloted_changed(node_id: String, is_piloted: bool)
signal node_operated(node_id: String, state: bool)

@export var entity_id: String = "node_01"
@export var clearance_level: int = 0
@export var toggled_state: bool = false

var is_piloted: bool = false
var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("infrastructure_nodes")
	# Layer 7: trigger (1 << 6 = 64)
	collision_layer = 1 << 6
	# Monitor Layer 3: machines
	collision_mask = 1 << 2

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
		rect.color = Color(0.2, 0.8, 0.4, 0.8) # Bright emerald data port
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

func on_seized(_world: Node2D) -> void:
	is_piloted = true
	if visual_rect != null:
		visual_rect.color = Color(0.9, 0.9, 0.2, 1.0) # Yellow piloted indicator
	node_piloted_changed.emit(entity_id, true)
	# Automatically operate linked machinery upon seizing the node
	operate_node()

func on_exited() -> void:
	is_piloted = false
	if visual_rect != null:
		visual_rect.color = Color(0.2, 0.8, 0.4, 0.8)
	node_piloted_changed.emit(entity_id, false)

func operate_node() -> void:
	toggled_state = not toggled_state
	node_operated.emit(entity_id, toggled_state)
	var world: Node = get_parent()
	while world != null and not (world is World):
		world = world.get_parent()
	if world != null and world.has_method("trigger_links"):
		world.call("trigger_links", entity_id, toggled_state)
