class_name ScrapPickup
extends Area2D

@export var amount: int = 1
var velocity: Vector2 = Vector2.ZERO
var friction: float = 400.0

func _ready() -> void:
	add_to_group("pickups")
	# Layer 7: trigger (1 << 6 = 64)
	collision_layer = 1 << 6
	# Monitor Layer 3: machines (1 << 2 = 4)
	collision_mask = 1 << 2

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func step(delta: float) -> void:
	if velocity != Vector2.ZERO:
		position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		queue_redraw()

func _draw() -> void:
	# Gold/amber diamond scrap
	var points: PackedVector2Array = [
		Vector2(0, -4),
		Vector2(4, 0),
		Vector2(0, 4),
		Vector2(-4, 0)
	]
	draw_colored_polygon(points, Color(1.0, 0.82, 0.2, 0.95))
	draw_polyline(points, Color(1.0, 1.0, 0.7, 1.0), 1.0)

func collect(collector: Node) -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		var root: Window = tree.root
		var game_node: Node = root.get_node_or_null("Game")
		if game_node != null:
			var cur_scrap: int = int(game_node.get("scrap"))
			game_node.set("scrap", cur_scrap + amount)
		var events_node: Node = root.get_node_or_null("Events")
		if events_node != null and events_node.has_signal("pickup_taken"):
			events_node.emit_signal("pickup_taken", "scrap", "currency", amount)

	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Machine:
		var m: Machine = body as Machine
		if m.operational_state == "player" or m.is_in_group("player"):
			collect(m)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("cursor") or (area.owner != null and area.owner.is_in_group("player")):
		collect(area)
