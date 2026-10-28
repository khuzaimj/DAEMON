class_name BeamGate
extends StaticBody2D

signal beam_gate_state_changed(gate_id: String, is_active: bool)

@export var entity_id: String = "beam_gate_01"
@export var is_energized: bool = false
@export var open_when_energized: bool = true
@export var beam_length_px: float = 48.0
@export var beam_direction: Vector2 = Vector2.DOWN

var is_beam_active: bool = true
var collider: CollisionShape2D = null
var visual_rect: ColorRect = null

func _ready() -> void:
	add_to_group("beam_gates")
	# Layer 1: solid
	collision_layer = 1
	collision_mask = 0

	collider = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		col_node.shape = rect_shape
		col_node.name = "CollisionShape2D"
		add_child(col_node)
		collider = col_node

	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	_update_shape()
	set_active(is_energized)

func _update_shape() -> void:
	var w: float = beam_length_px if beam_direction.x != 0.0 else 16.0
	var h: float = 16.0 if beam_direction.x != 0.0 else beam_length_px
	if collider != null:
		(collider.shape as RectangleShape2D).size = Vector2(w, h)
		if beam_direction.x != 0.0:
			collider.position = Vector2(beam_direction.x * beam_length_px * 0.5, 0.0)
		else:
			collider.position = Vector2(0.0, beam_direction.y * beam_length_px * 0.5)

	if visual_rect != null:
		visual_rect.size = Vector2(w, h)
		if beam_direction.x != 0.0:
			visual_rect.position = Vector2(0.0 if beam_direction.x > 0 else -beam_length_px, -8.0)
		else:
			visual_rect.position = Vector2(-8.0, 0.0 if beam_direction.y > 0 else -beam_length_px)

func set_active(energized: bool) -> void:
	is_energized = energized
	if open_when_energized:
		is_beam_active = not is_energized
	else:
		is_beam_active = is_energized

	if collider != null:
		collider.disabled = not is_beam_active
	if visual_rect != null:
		if is_beam_active:
			visual_rect.color = Color(0.2, 0.9, 1.0, 0.85) # Electric cyan barrier
			visual_rect.visible = true
		else:
			visual_rect.color = Color(0.1, 0.3, 0.4, 0.15) # Powered down
			visual_rect.visible = false

	beam_gate_state_changed.emit(entity_id, is_beam_active)
