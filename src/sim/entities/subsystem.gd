class_name Subsystem
extends Machine

## Subsystem: A hijackable boss component (actuator, lens, valve).
## Can be targeted and seized by the player daemon to damage or advance the boss fight.

signal subsystem_overloaded(sub_id: String)

@export var subsystem_id: String = "actuator_1"
@export var boss_id: String = "bootloader"
@export var subsystem_type: String = "actuator"
@export var target_phase: int = 1
@export var is_active_in_phase: bool = false
@export var is_disabled: bool = false

func _init(p_sub_id: String = "actuator_1", p_type: String = "actuator") -> void:
	subsystem_id = p_sub_id
	subsystem_type = p_type
	entity_id = p_sub_id
	is_immune_unit = false
	is_boss_body = false
	operational_state = "hostile"
	faction = "hostile"

func _ready() -> void:
	is_immune_unit = false
	is_boss_body = false
	operational_state = "hostile"
	faction = "hostile"
	entity_id = subsystem_id

	_ensure_components()
	_setup_subsystem_data()

func _ensure_components() -> void:
	if collider == null:
		var col_node: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(16, 16)
		col_node.shape = rect_shape
		col_node.name = "Collider"
		add_child(col_node)
		collider = col_node

	if hurt_box == null:
		var hb: Area2D = Area2D.new()
		hb.name = "HurtBox"
		hb.collision_layer = 1 << 5 # Layer 6: hurtbox (32)
		hb.collision_mask = (1 << 4) | (1 << 8)
		var hb_shape: CollisionShape2D = CollisionShape2D.new()
		var hb_rect: RectangleShape2D = RectangleShape2D.new()
		hb_rect.size = Vector2(16, 16)
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
		rect.size = Vector2(16, 16)
		rect.position = Vector2(-8, -8)
		add_child(rect)
		visual_rect = rect

func _setup_subsystem_data() -> void:
	size_class = "s"
	body_id = "actuator"
	state.setup_from_dict({
		"integrity": 10,
		"heat_max": 100.0,
		"heat_cooldown": 20.0
	})
	# Subsystem is always Open when active in current phase
	state.open_threshold = 1.0

	_apply_size_class()
	_update_visual()

func set_phase_active(active: bool) -> void:
	is_active_in_phase = active
	if is_disabled:
		is_active_in_phase = false
	_update_visual()

func _update_visual() -> void:
	if visual_rect == null:
		return
	if is_disabled:
		visual_rect.color = Color(0.2, 0.2, 0.25, 0.6) # Disabled dark slate
	elif is_active_in_phase:
		visual_rect.color = Color(0.1, 0.9, 0.9, 1.0) # Bright cyan - ready for hijack!
	else:
		visual_rect.color = Color(0.6, 0.2, 0.2, 0.8) # Dormant red/locked

func is_open() -> bool:
	# Hijack candidate test checks is_open()
	return is_active_in_phase and not is_disabled

## Called when daemon seizes or triggers this subsystem
func trigger_overload() -> void:
	if is_disabled:
		return
	is_disabled = true
	is_active_in_phase = false
	_update_visual()
	subsystem_overloaded.emit(subsystem_id)
