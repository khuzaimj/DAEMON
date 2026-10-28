class_name Switch
extends Area2D

signal switch_toggled(switch_id: String, is_on: bool)

@export var entity_id: String = "switch_01"
@export var is_on: bool = false
@export var can_interact: bool = true
@export var can_hit: bool = true

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("switches")
	# Layer 7: trigger (64)
	collision_layer = 1 << 6
	# Monitor Layer 5: hitbox (16)
	collision_mask = 1 << 4

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
		rect.size = Vector2(12, 12)
		rect.position = Vector2(-6, -6)
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	area_entered.connect(_on_area_entered)
	set_active(is_on)

func _on_area_entered(area: Area2D) -> void:
	if can_hit and (area.collision_layer & (1 << 4)):
		trigger()

func take_damage(_amount: int, _damage_type: String = "kinetic", _ignore_invuln: bool = false, _impact_dir: Vector2 = Vector2.ZERO) -> bool:
	if can_hit:
		trigger()
		return true
	return false

func trigger() -> void:
	var world_node: World = _find_world()
	if world_node != null and world_node.get("logic_system") != null:
		var ls: Object = world_node.get("logic_system")
		if ls.has_method("trigger_switch"):
			ls.call("trigger_switch", entity_id)

func set_active(active: bool) -> void:
	is_on = active
	if visual_rect != null:
		if is_on:
			visual_rect.color = Color(0.1, 0.9, 0.8, 1.0) # Active cyan
		else:
			visual_rect.color = Color(0.4, 0.3, 0.15, 0.8) # Inactive amber/brown
	switch_toggled.emit(entity_id, is_on)

func _find_world() -> World:
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	return n as World
