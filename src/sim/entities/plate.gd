class_name Plate
extends Area2D

signal plate_pressed_changed(plate_id: String, is_pressed: bool)

@export var entity_id: String = "plate_01"
@export var weight_threshold: int = 1
@export var is_latched: bool = false # Once latched, never unpresses

var is_pressed: bool = false
var collider: CollisionShape2D = null
var visual_rect: ColorRect = null
var pressing_machines: Array[Machine] = []

func _ready() -> void:
	add_to_group("plates")
	# Layer 7: trigger (1 << 6 = 64)
	collision_layer = 1 << 6
	# Monitor Layer 3: machines (1 << 2 = 4) and Layer 4: pushables (1 << 3 = 8)
	collision_mask = (1 << 2) | (1 << 3)

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
		rect.size = Vector2(14, 14)
		rect.position = Vector2(-7, -7)
		rect.color = Color(0.5, 0.4, 0.2, 0.6) # Copper pressure plate
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	body_entered.connect(_on_body_event)
	body_exited.connect(_on_body_event)

func _on_body_event(_b: Node2D) -> void:
	check_weight()

## Stepped or called on body changes
func check_weight() -> void:
	if is_latched and is_pressed:
		return

	# Reset is_holding_latch on previously pressing machines
	for prev_m: Machine in pressing_machines:
		if is_instance_valid(prev_m):
			prev_m.set_meta("is_holding_latch", false)
	pressing_machines.clear()

	var current_weight: int = 0
	var candidates: Array[Node2D] = []
	for b: Node2D in get_overlapping_bodies():
		if not candidates.has(b):
			candidates.append(b)

	# Immediate bounds check against world machines & crates
	var plate_rect: Rect2 = Rect2(global_position - Vector2(8, 8), Vector2(16, 16))
	var world_node: Node = get_parent()
	while world_node != null and not (world_node is World):
		world_node = world_node.get_parent()

	if world_node != null and world_node is World:
		var w: World = world_node as World
		for m: Machine in w.machines:
			if is_instance_valid(m) and not candidates.has(m):
				var m_rect: Rect2 = Rect2(m.global_position - Vector2(8, 8), Vector2(16, 16))
				if plate_rect.intersects(m_rect):
					candidates.append(m)
		if w.entities_container != null:
			for child: Node in w.entities_container.get_children():
				if (child is Machine or child is Crate) and not candidates.has(child):
					var c_2d: Node2D = child as Node2D
					var c_rect: Rect2 = Rect2(c_2d.global_position - Vector2(8, 8), Vector2(16, 16))
					if plate_rect.intersects(c_rect):
						candidates.append(c_2d)

	var candidate_machines: Array[Machine] = []
	for b: Node2D in candidates:
		if b is Machine:
			var m: Machine = b as Machine
			current_weight += m.weight
			candidate_machines.append(m)
		elif b is Crate:
			var c: Crate = b as Crate
			current_weight += c.weight

	var should_press: bool = current_weight >= weight_threshold
	if should_press or is_latched:
		for m: Machine in candidate_machines:
			m.set_meta("is_holding_latch", true)
			if not pressing_machines.has(m):
				pressing_machines.append(m)

	if should_press != is_pressed:
		set_pressed(should_press)

func set_pressed(pressed: bool) -> void:
	if is_latched and is_pressed and not pressed:
		return # Cannot unpress if latched
	is_pressed = pressed
	if visual_rect != null:
		if is_pressed:
			visual_rect.color = Color(0.9, 0.7, 0.1, 0.9) # Bright active amber
		else:
			visual_rect.color = Color(0.5, 0.4, 0.2, 0.6)

	plate_pressed_changed.emit(entity_id, is_pressed)

	# Trigger linked targets in World
	var world: Node = get_parent()
	while world != null and not (world is World):
		world = world.get_parent()
	if world != null and world.has_method("trigger_links"):
		world.call("trigger_links", entity_id, is_pressed)
