class_name ParkedState
extends RefCounted

var routine: String = "hold" # "hold", "guard", "patrol", "repeat"
var park_origin_pos: Vector2 = Vector2.ZERO
var pin_pos: Vector2 = Vector2.ZERO
var patrol_forward: bool = true
var locked_facing: Vector2 = Vector2.DOWN

func _init(p_routine: String = "hold", p_origin: Vector2 = Vector2.ZERO, p_pin: Vector2 = Vector2.ZERO, p_facing: Vector2 = Vector2.DOWN) -> void:
	routine = p_routine
	park_origin_pos = p_origin
	pin_pos = p_pin
	locked_facing = p_facing
	patrol_forward = true

func get_current_patrol_target() -> Vector2:
	return pin_pos if patrol_forward else park_origin_pos

func check_patrol_arrival(current_pos: Vector2, threshold_px: float = 4.0) -> void:
	var target: Vector2 = get_current_patrol_target()
	if current_pos.distance_to(target) <= threshold_px:
		patrol_forward = not patrol_forward
