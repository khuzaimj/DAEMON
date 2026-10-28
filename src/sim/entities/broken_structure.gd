class_name BrokenStructure
extends StaticBody2D

signal structure_repaired(structure_id: String)

@export var entity_id: String = "broken_structure_01"
@export var is_repaired: bool = false
@export var repair_progress: float = 0.0
@export var repair_needed: float = 1.0

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("broken_structures")
	collision_layer = 1 # Solid obstacle until repaired or acts as interactive terminal
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
		rect.color = Color(0.35, 0.25, 0.2, 1.0) # Rusty damaged console
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	set_repaired(is_repaired)

func apply_repair(amount: float, _source: Node = null) -> void:
	if is_repaired:
		return
	repair_progress += amount
	if repair_progress >= repair_needed:
		set_repaired(true)
		var world_node: World = _find_world()
		if world_node != null and world_node.get("logic_system") != null:
			var ls: Object = world_node.get("logic_system")
			if ls.has_method("force_state"):
				ls.call("force_state", entity_id, true)

func set_repaired(repaired: bool) -> void:
	is_repaired = repaired
	if is_repaired:
		repair_progress = repair_needed
		if visual_rect != null:
			visual_rect.color = Color(0.2, 0.8, 1.0, 0.9) # Online glowing cyan
		structure_repaired.emit(entity_id)
	else:
		if visual_rect != null:
			visual_rect.color = Color(0.35, 0.25, 0.2, 1.0)

func _find_world() -> World:
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	return n as World
