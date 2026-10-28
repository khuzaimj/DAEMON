class_name LogPickup
extends Area2D

@export var entity_id: String = ""
@export var log_id: String = ""
@export var log_title: String = ""
@export var log_text: String = ""

var is_collected: bool = false

func _ready() -> void:
	add_to_group("pickups")
	add_to_group("logs")
	# Layer 7: trigger (64)
	collision_layer = 1 << 6
	# Monitor Layer 3: machines (4)
	collision_mask = 1 << 2

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _draw() -> void:
	# Slate border and glowing screen
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.15, 0.2, 0.25))
	draw_rect(Rect2(-4, -4, 8, 8), Color(0.2, 0.8, 0.7, 0.9))
	draw_line(Vector2(-3, -2), Vector2(3, -2), Color.WHITE, 1.0)
	draw_line(Vector2(-3, 0), Vector2(2, 0), Color.WHITE, 1.0)
	draw_line(Vector2(-3, 2), Vector2(1, 2), Color.WHITE, 1.0)

func collect(_collector: Node) -> void:
	if is_collected:
		return
	is_collected = true

	var tree: SceneTree = get_tree()
	if tree != null:
		var root: Window = tree.root
		var game_node: Node = root.get_node_or_null("Game")
		if game_node != null and game_node.has_method("add_log"):
			game_node.call("add_log", log_id)

		var events_node: Node = root.get_node_or_null("Events")
		if events_node != null and events_node.has_signal("log_found"):
			events_node.emit_signal("log_found", log_id)

	# Record in room's taken pickups
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	if n != null and n is World:
		var w: World = n as World
		if entity_id != "" and w.has_method("record_taken_pickup"):
			w.call("record_taken_pickup", entity_id)

	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Machine:
		var m: Machine = body as Machine
		if m.operational_state == "player" or m.is_in_group("player"):
			collect(m)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("cursor") or (area.owner != null and area.owner.is_in_group("player")):
		collect(area)
