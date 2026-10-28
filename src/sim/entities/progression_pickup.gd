class_name ProgressionPickup
extends Area2D

@export var entity_id: String = ""
@export var pickup_kind: String = "integrity_chip"
@export var amount: int = 1
@export var clearance_level: int = 1

var is_collected: bool = false

func _ready() -> void:
	add_to_group("pickups")
	add_to_group("progression_pickups")
	# Layer 7: trigger (64)
	collision_layer = 1 << 6
	# Monitor Layer 3: machines (4)
	collision_mask = 1 << 2

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _draw() -> void:
	match pickup_kind:
		"integrity_chip":
			# Green cross
			draw_rect(Rect2(-6, -2, 12, 4), Color(0.2, 0.9, 0.3))
			draw_rect(Rect2(-2, -6, 4, 12), Color(0.2, 0.9, 0.3))
		"heat_sink":
			# Cyan fin
			draw_rect(Rect2(-5, -5, 10, 10), Color(0.1, 0.7, 0.9))
			draw_line(Vector2(-3, -5), Vector2(-3, 5), Color.WHITE, 1.0)
			draw_line(Vector2(0, -5), Vector2(0, 5), Color.WHITE, 1.0)
			draw_line(Vector2(3, -5), Vector2(3, 5), Color.WHITE, 1.0)
		"link_range":
			# Purple concentric ring
			draw_arc(Vector2.ZERO, 5.0, 0, TAU, 12, Color(0.8, 0.3, 0.9), 2.0)
			draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
		"ttl_extender":
			# Yellow spark
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.9, 0.1))
			draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
		"garage_slot":
			# Blue container icon
			draw_rect(Rect2(-6, -6, 12, 12), Color(0.2, 0.4, 0.85))
			draw_rect(Rect2(-4, -4, 8, 8), Color(0.1, 0.2, 0.5))
		"clearance":
			# Gold badge
			draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.8, 0.1))
			draw_circle(Vector2.ZERO, 3.0, Color(0.4, 0.2, 0.0))
		"shard":
			# Red crystal diamond
			var pts: PackedVector2Array = [Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)]
			draw_colored_polygon(pts, Color(0.95, 0.15, 0.2))
			draw_polyline(pts, Color(1.0, 0.6, 0.6), 1.0)
		"bus_pass":
			# White/blue transit card
			draw_rect(Rect2(-7, -5, 14, 10), Color(0.2, 0.5, 0.85))
			draw_rect(Rect2(-5, -3, 10, 6), Color.WHITE)
		_:
			draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.9, 0.9))

func collect(collector: Node) -> void:
	if is_collected:
		return
	is_collected = true

	var tree: SceneTree = get_tree()
	if tree != null:
		var root: Window = tree.root
		var game_node: Node = root.get_node_or_null("Game")
		if game_node != null and game_node.has_method("add_upgrade"):
			if pickup_kind == "clearance":
				game_node.call("add_upgrade", "clearance", clearance_level)
			else:
				game_node.call("add_upgrade", pickup_kind, amount)

		var events_node: Node = root.get_node_or_null("Events")
		if events_node != null and events_node.has_signal("pickup_taken"):
			events_node.emit_signal("pickup_taken", entity_id, pickup_kind, amount)

	# Apply immediate stat bonus to live host machine
	var m: Machine = null
	if collector is Machine:
		m = collector as Machine
	elif collector != null and collector.get("player_machine") is Machine:
		m = collector.get("player_machine") as Machine

	if m != null and m.state != null:
		if pickup_kind == "heat_sink":
			m.state.max_heat += 10.0 * float(amount)
		elif pickup_kind == "integrity_chip":
			m.state.max_integrity += amount
			m.state.current_integrity += amount

	# Record in room's taken pickups
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	if n != null and n is World:
		var w: World = n as World
		if entity_id != "" and w.has_method("record_taken_pickup"):
			w.call("record_taken_pickup", entity_id)
		if w.has_method("sync_fsm_with_game"):
			w.call("sync_fsm_with_game")

	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Machine:
		var m: Machine = body as Machine
		if m.operational_state == "player" or m.is_in_group("player"):
			collect(m)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("cursor") or (area.owner != null and area.owner.is_in_group("player")):
		collect(area)
