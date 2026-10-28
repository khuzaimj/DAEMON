class_name Lift
extends CharacterBody2D

signal lift_state_changed(lift_id: String, is_active: bool)

@export var entity_id: String = "lift_01"
@export var is_active: bool = false
@export var travel_distance: float = 64.0
@export var travel_direction: Vector2 = Vector2.DOWN
@export var travel_speed: float = 32.0

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("lifts")
	collision_layer = 1 # Solid platform
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	start_pos = position
	target_pos = start_pos + travel_direction.normalized() * travel_distance

	collider = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(24, 16)
		col_node.shape = rect_shape
		col_node.name = "CollisionShape2D"
		add_child(col_node)
		collider = col_node

	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(24, 16)
		rect.position = Vector2(-12, -8)
		rect.color = Color(0.4, 0.45, 0.5, 1.0)
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

func set_active(active: bool) -> void:
	is_active = active
	lift_state_changed.emit(entity_id, is_active)

func step(delta: float) -> void:
	var dest: Vector2 = target_pos if is_active else start_pos
	if position.distance_to(dest) > 0.5:
		var old_pos: Vector2 = position
		position = position.move_toward(dest, travel_speed * delta)
		var move_delta: Vector2 = position - old_pos
		_carry_overlapping(move_delta)

func _carry_overlapping(move_delta: Vector2) -> void:
	var world_node: World = _find_world()
	if world_node == null:
		return
	var lift_rect: Rect2 = Rect2(global_position - Vector2(12, 8), Vector2(24, 16))
	for m: Machine in world_node.machines:
		if is_instance_valid(m) and lift_rect.has_point(m.global_position):
			m.position += move_delta
	for c: Crate in world_node.crates:
		if is_instance_valid(c) and lift_rect.has_point(c.global_position):
			c.position += move_delta

func _find_world() -> World:
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	return n as World
