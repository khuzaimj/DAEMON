class_name FirewallNode
extends Firewall

## FirewallNode: Projects barrier lines that block hops; disabled from maintenance Node.

@export var barrier_length_px: float = 48.0
@export var barrier_direction: Vector2 = Vector2.DOWN
var is_immune_unit: bool = true

func _ready() -> void:
	add_to_group("firewall_nodes")
	super._ready()
	_update_barrier_shape()

func _update_barrier_shape() -> void:
	if collider != null:
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		if barrier_direction.x != 0.0:
			rect_shape.size = Vector2(barrier_length_px, 16.0)
			collider.position = Vector2(barrier_direction.x * barrier_length_px * 0.5, 0.0)
		else:
			rect_shape.size = Vector2(16.0, barrier_length_px)
			collider.position = Vector2(0.0, barrier_direction.y * barrier_length_px * 0.5)
		collider.shape = rect_shape

	if visual_rect != null:
		if barrier_direction.x != 0.0:
			visual_rect.size = Vector2(barrier_length_px, 16.0)
			visual_rect.position = Vector2(0.0 if barrier_direction.x > 0 else -barrier_length_px, -8.0)
		else:
			visual_rect.size = Vector2(16.0, barrier_length_px)
			visual_rect.position = Vector2(-8.0, 0.0 if barrier_direction.y > 0 else -barrier_length_px)
