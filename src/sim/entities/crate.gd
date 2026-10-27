class_name Crate
extends CharacterBody2D

@export var size_class: String = "m"
@export var weight: int = 1
@export var is_carried: bool = false
@export var carrier: Machine = null

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	# Layer 4: pushables (8)
	collision_layer = 1 << (4 - 1)
	# Collides with solid (1), machines (3), pushables (4), pit (10)
	collision_mask = (1 << (1 - 1)) | (1 << (3 - 1)) | (1 << (4 - 1)) | (1 << (10 - 1))
	
	collider = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(12, 12)
		col_node.shape = rect_shape
		col_node.name = "CollisionShape2D"
		add_child(col_node)
		collider = col_node
		
	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(12, 12)
		rect.position = Vector2(-6, -6)
		rect.color = Color(0.6, 0.45, 0.25, 1.0) # Wood crate brown
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

## Stepped once per tick by World movement system
func step_movement(delta: float) -> void:
	if is_carried and carrier != null and is_instance_valid(carrier):
		global_position = carrier.global_position + carrier.facing * 14.0
		return

	if not is_carried and velocity.length_squared() > 1.0:
		var motion: Vector2 = velocity * delta
		var col: KinematicCollision2D = move_and_collide(motion)
		if col != null:
			velocity = velocity.slide(col.get_normal()) * 0.5
		# Apply friction decay
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		if velocity.length_squared() <= 1.0:
			velocity = Vector2.ZERO
