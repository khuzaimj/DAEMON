class_name ImmuneUnit
extends Machine

## ImmuneUnit: Non-hijackable immune system entities
## glitch_mite, antivirus_sentinel, quarantine_pod, garbage_collector

@export var immune_type: String = "glitch_mite"
var immune_controller: ImmuneController = null

func _init(p_type: String = "glitch_mite") -> void:
	immune_type = p_type
	is_immune_unit = true
	faction = "hostile"
	operational_state = "hostile"
	_ensure_components()

func _ready() -> void:
	is_immune_unit = true
	faction = "hostile"
	operational_state = "hostile"

	if entity_id.is_empty():
		entity_id = "%s_%d" % [immune_type, get_instance_id()]

	_ensure_components()
	setup_immune(immune_type)

func _exit_tree() -> void:
	if immune_controller != null:
		immune_controller.release_trapped_hosts()

func take_damage(amount: int, damage_type: String = "kinetic", ignore_invuln: bool = false, impact_dir: Vector2 = Vector2.ZERO) -> bool:
	var took: bool = super.take_damage(amount, damage_type, ignore_invuln, impact_dir)
	if state != null and state.current_integrity <= 0:
		if immune_controller != null:
			immune_controller.release_trapped_hosts()
	return took

func _ensure_components() -> void:
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(8, 8)
		col_node.shape = rect_shape
		col_node.name = "Collider"
		add_child(col_node)
		collider = col_node

	if hurt_box == null:
		var hb: Area2D = Area2D.new()
		hb.name = "HurtBox"
		# Layer 6: hurtbox (32)
		hb.collision_layer = 1 << 5
		hb.collision_mask = (1 << 4) | (1 << 8)
		var hb_shape: CollisionShape2D = CollisionShape2D.new()
		var hb_rect: RectangleShape2D = RectangleShape2D.new()
		hb_rect.size = Vector2(8, 8)
		hb_shape.shape = hb_rect
		hb_shape.name = "CollisionShape2D"
		hb.add_child(hb_shape)
		add_child(hb)
		hurt_box = hb
		hurt_shape = hb_shape
		hb.area_entered.connect(_on_hurtbox_area_entered)

	if visual_rect == null:
		var rect: ColorRect = ColorRect.new()
		rect.name = "PlaceholderVisual"
		rect.size = Vector2(8, 8)
		rect.position = Vector2(-4, -4)
		add_child(rect)
		visual_rect = rect

func setup_immune(p_type: String) -> void:
	immune_type = p_type
	body_id = p_type
	enemy_id = p_type

	var hp: int = 1
	var spd: float = 6.0
	var sz: String = "xs"
	var scrap_range: Array = [1, 1]
	var col: Color = Color(0.9, 0.2, 0.8)

	match p_type:
		"glitch_mite":
			hp = 1
			spd = 6.0
			sz = "xs"
			scrap_range = [1, 1]
			col = Color(0.9, 0.2, 0.8)
		"antivirus_sentinel":
			hp = 6
			spd = 4.0
			sz = "s"
			scrap_range = [2, 3]
			col = Color(1.0, 0.2, 0.2)
		"quarantine_pod":
			hp = 6
			spd = 0.0
			sz = "s"
			scrap_range = [2, 3]
			col = Color(0.9, 0.8, 0.1)
		"garbage_collector":
			hp = 16
			spd = 2.5
			sz = "l"
			scrap_range = [3, 5]
			col = Color(0.3, 0.3, 0.35)

	size_class = sz
	base_speed_tiles = spd
	enemy_data = {
		"drops": { "scrap": scrap_range }
	}

	state.setup_from_dict({
		"integrity": hp,
		"heat_max": 100.0,
		"heat_cooldown": 20.0
	})
	_apply_size_class()

	if visual_rect != null:
		var half_sz: float = collider.shape.get_rect().size.x * 0.5 if collider != null and collider.shape != null else 4.0
		visual_rect.size = Vector2(half_sz * 2.0, half_sz * 2.0)
		visual_rect.position = Vector2(-half_sz, -half_sz)
		visual_rect.color = col

	# Attach ImmuneController
	var old_c: Node = get_node_or_null("Controller")
	if old_c != null and old_c != immune_controller:
		remove_child(old_c)
		old_c.free()

	immune_controller = ImmuneController.new(immune_type)
	immune_controller.name = "Controller"
	add_child(immune_controller)
	controller = immune_controller
