class_name Dock
extends Area2D

signal dock_activated(dock_id: String)
signal body_fabricated(machine: Machine)

@export var entity_id: String = "dock_01"
@export var bay_offset: Vector2 = Vector2(0, 24.0) # Position where fabricated bodies appear

var collider: CollisionShape2D = null
var visual_rect: ColorRect = null
var is_active: bool = false

func _ready() -> void:
	add_to_group("docks")
	# Layer 7: trigger (1 << 6 = 64)
	collision_layer = 1 << 6
	# Monitor Layer 3: machines (1 << 2 = 4)
	collision_mask = 1 << 2
	
	collider = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(32, 32)
		col_node.shape = rect_shape
		col_node.name = "CollisionShape2D"
		add_child(col_node)
		collider = col_node
		
	visual_rect = get_node_or_null("ColorRect") as ColorRect
	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(32, 32)
		rect.position = Vector2(-16, -16)
		rect.color = Color(0.1, 0.4, 0.5, 0.4) # Cyan dock pad
		rect.name = "ColorRect"
		add_child(rect)
		visual_rect = rect

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Machine:
		var m: Machine = body as Machine
		if m.operational_state == "player":
			activate_dock(m)

func activate_dock(player_m: Machine) -> void:
	is_active = true
	var tree: SceneTree = get_tree()
	if tree != null:
		var root: Window = tree.root
		var game_node: Node = root.get_node_or_null("Game")
		if game_node != null:
			var current_room: String = str(game_node.get("current_room_id"))
			game_node.set("last_dock_room_id", current_room)
			game_node.set("last_dock_spawn_pos", global_position)
			var visited: Array = game_node.get("visited_docks")
			if not visited.has(entity_id):
				visited.append(entity_id)

		var events_node: Node = root.get_node_or_null("Events")
		if events_node != null:
			events_node.emit_signal("dock_visited", entity_id, game_node.get("current_room_id") if game_node != null else "")

	# Heal and cool host
	if player_m != null and player_m.state != null:
		player_m.state.repair(player_m.state.max_integrity)
		player_m.state.current_heat = 0.0
		player_m.state.heat_changed.emit(0.0, player_m.state.max_heat)

	dock_activated.emit(entity_id)

func can_fabricate(model_id: String, registered_models: Array[String], player_scrap: int) -> bool:
	if not registered_models.has(model_id):
		return false
	var cost: int = get_model_cost(model_id)
	return player_scrap >= cost

func get_model_cost(model_id: String) -> int:
	var body_dict: Dictionary = _get_body_data(model_id)
	return int(body_dict.get("garage_cost", 10))

func fabricate(model_id: String, world: Node2D) -> Machine:
	var tree: SceneTree = get_tree()
	var game_node: Node = tree.root.get_node_or_null("Game") if tree != null else null
	var scrap_avail: int = int(game_node.get("scrap")) if game_node != null else 999
	var cost: int = get_model_cost(model_id)
	if scrap_avail < cost:
		return null
	if game_node != null:
		game_node.set("scrap", scrap_avail - cost)

	var scene: PackedScene = load("res://scenes/machine.tscn")
	if scene == null:
		return null
	var m: Machine = scene.instantiate() as Machine
	m.entity_id = "fab_%s_%d" % [model_id, Time.get_ticks_msec()]
	m.position = global_position + bay_offset
	m.operational_state = "dormant"

	var null_ctrl: NullController = NullController.new()
	null_ctrl.name = "Controller"
	var old_ctrl: Node = m.get_node_or_null("Controller")
	if old_ctrl != null:
		m.remove_child(old_ctrl)
		old_ctrl.queue_free()
	m.add_child(null_ctrl)
	m.controller = null_ctrl

	var body_dict: Dictionary = _get_body_data(model_id)
	if not body_dict.is_empty():
		m.apply_body_data(body_dict)

	if world != null and world.has_method("register_machine"):
		var entities: Node = world.get_node_or_null("Entities")
		if entities != null:
			entities.add_child(m)
		else:
			world.add_child(m)
		world.call("register_machine", m)

	body_fabricated.emit(m)
	return m

func _get_body_data(model_id: String) -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree != null:
		var data_node: Node = tree.root.get_node_or_null("Data")
		if data_node != null and data_node.has_method("get_json"):
			var raw: Variant = data_node.call("get_json", "res://data/bodies/%s.json" % model_id)
			if raw is Dictionary:
				return raw as Dictionary
	if FileAccess.file_exists("res://data/bodies/%s.json" % model_id):
		var file: FileAccess = FileAccess.open("res://data/bodies/%s.json" % model_id, FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				return json.data as Dictionary
	return {}
