class_name Machine
extends CharacterBody2D

@export var body_id: String = "cursor"
@export var size_class: String = "xs"
@export var base_speed_tiles: float = 7.0 # Tiles per second
@export var weight: int = 0
@export var mediums: Array[String] = ["ground"]
@export var primary_ability: String = "ping"
@export var secondary_ability: String = ""

var current_room: RoomRuntime = null
var controller: Controller = null
var current_intent: Intent = Intent.new()
var state: BodyState = BodyState.new()
var facing: Vector2 = Vector2.DOWN

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_speed_px: float = 0.0
var dash_ticks_left: int = 0
var dash_breaks_cracked: bool = false
var dash_bypasses_pit: bool = false

@onready var collider: CollisionShape2D = $Collider
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var glow: AnimatedSprite2D = $Glow
@onready var hurt_box: Area2D = $HurtBox
@onready var hurt_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var abilities: AbilitiesRunner = $Abilities
@onready var visual_rect: ColorRect = $PlaceholderVisual

func _ready() -> void:
	if controller == null:
		controller = get_node_or_null("Controller") as Controller
	if abilities == null:
		abilities = get_node_or_null("Abilities") as AbilitiesRunner
	_apply_size_class()
	if abilities != null:
		abilities.setup(self, primary_ability, secondary_ability)
	if hurt_box != null:
		hurt_box.area_entered.connect(_on_hurtbox_area_entered)

func _process(_delta: float) -> void:
	if visual_rect == null:
		return
	if state.is_crashed:
		visual_rect.color = Color(0.2, 0.2, 0.2, 1.0)
	elif state.is_overheated:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.015)
		visual_rect.color = Color(1.0, 0.2 + 0.3 * pulse, 0.0, 1.0)
	elif state.invulnerability_ticks > 0:
		var flash: bool = (state.invulnerability_ticks % 6) < 3
		var base_col: Color = _get_default_color_for_body()
		visual_rect.color = Color(base_col.r, base_col.g, base_col.b, 0.4 if flash else 1.0)
	elif state.is_open():
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.01)
		var base_col: Color = _get_default_color_for_body()
		visual_rect.color = base_col.lerp(Color.WHITE, 0.5 * pulse)
	else:
		visual_rect.color = _get_default_color_for_body()

func _get_default_color_for_body() -> Color:
	match body_id.to_lower():
		"cursor": return Color(0.1, 0.8, 0.9, 1.0) # Cyan
		"janitor": return Color(0.9, 0.7, 0.2, 1.0) # Amber
		"loader": return Color(0.8, 0.5, 0.1, 1.0) # Rust
		"sentry": return Color(0.4, 0.7, 0.8, 1.0) # Steel Cyan
		"drone": return Color(0.7, 0.3, 0.9, 1.0) # Neon Violet
		"welder": return Color(0.9, 0.4, 0.1, 1.0) # Fire Orange
		"diver": return Color(0.1, 0.6, 0.6, 1.0) # Deep Teal
		"crawler": return Color(0.4, 0.7, 0.3, 1.0) # Olive Green
		"courier": return Color(0.9, 0.9, 0.2, 1.0) # Yellow
		"medic": return Color(0.9, 0.9, 0.9, 1.0) # White
		_: return Color(0.1, 0.8, 0.9, 1.0)

func apply_body_data(data: Dictionary) -> void:
	body_id = str(data.get("id", body_id))
	size_class = str(data.get("size", size_class))
	base_speed_tiles = float(data.get("speed", base_speed_tiles))
	weight = int(data.get("weight", weight))
	primary_ability = str(data.get("primary", ""))
	secondary_ability = str(data.get("secondary", ""))
	
	var med_val: Variant = data.get("medium", ["ground"])
	mediums.clear()
	if med_val is Array:
		for m: Variant in med_val:
			mediums.append(str(m))
			
	state.setup_from_dict(data)
	_apply_size_class()
	if abilities != null:
		abilities.setup(self, primary_ability, secondary_ability)

func take_damage(amount: int, damage_type: String = "kinetic", ignore_invuln: bool = false) -> bool:
	return state.take_damage(amount, damage_type, ignore_invuln)

func add_heat(amount: float) -> void:
	state.add_heat(amount)

func heal(amount: int) -> void:
	state.repair(amount)

func apply_status(status_name: String, duration_ticks: int) -> void:
	state.apply_status(status_name, duration_ticks)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.has_meta("damage"):
		var dmg: int = int(area.get_meta("damage"))
		var dmg_type: String = str(area.get_meta("damage_type", "kinetic"))
		take_damage(dmg, dmg_type)

func _apply_size_class() -> void:
	var hitbox_size: float = 8.0
	var sizes_data: Variant = null
	var data_node: Node = get_node_or_null("/root/Data")
	if data_node != null and data_node.has_method("get_json"):
		sizes_data = data_node.call("get_json", "res://data/sizes.json")
	elif FileAccess.file_exists("res://data/sizes.json"):
		var file: FileAccess = FileAccess.open("res://data/sizes.json", FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				sizes_data = json.data
	if sizes_data is Dictionary:
		var size_dict: Dictionary = (sizes_data as Dictionary).get("sizes", {})
		var entry: Dictionary = size_dict.get(size_class.to_lower(), {})
		hitbox_size = float(entry.get("hitbox_px", 8))

	if collider != null:
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(hitbox_size, hitbox_size)
		collider.shape = rect_shape

	if hurt_shape != null:
		var hurt_rect: RectangleShape2D = RectangleShape2D.new()
		hurt_rect.size = Vector2(hitbox_size, hitbox_size)
		hurt_shape.shape = hurt_rect

	if visual_rect != null:
		visual_rect.size = Vector2(hitbox_size, hitbox_size)
		visual_rect.position = -Vector2(hitbox_size * 0.5, hitbox_size * 0.5)

	# Configure collision layer and mask
	collision_layer = 1 << (3 - 1) # Layer 3: machines
	var mask_flags: int = (1 << (1 - 1)) | (1 << (3 - 1)) | (1 << (4 - 1)) # Layer 1: solid, 3: machines, 4: pushables
	if size_class.to_lower() != "xs":
		mask_flags |= (1 << (2 - 1)) # Layer 2: conduit_gate (blocks non-XS)
	if not mediums.has("hover"):
		mask_flags |= (1 << (10 - 1)) # Layer 10: pit (blocks non-hovering machines)
	collision_mask = mask_flags

## Called once per tick by World controllers system
func step_controller(tick: int) -> void:
	state.tick(1)
	if controller != null:
		current_intent = controller.decide(self, tick)
		
	# Update facing from move or aim
	if current_intent.aim != Vector2.ZERO:
		facing = AbilityMath.snap_to_8_way(current_intent.aim, facing)
	elif current_intent.move != Vector2.ZERO:
		facing = AbilityMath.snap_to_8_way(current_intent.move, facing)

## Called once per tick by World abilities system
func step_abilities(tick: int) -> void:
	if abilities != null:
		abilities.step(tick, current_intent)

func start_dash(dir: Vector2, speed_px: float, ticks: int, breaks_cracked: bool, bypasses_pit: bool, grant_invuln: bool) -> void:
	is_dashing = true
	dash_direction = dir
	dash_speed_px = speed_px
	dash_ticks_left = ticks
	dash_breaks_cracked = breaks_cracked
	dash_bypasses_pit = bypasses_pit
	if grant_invuln and state != null:
		state.invulnerability_ticks = maxi(state.invulnerability_ticks, ticks)
	if bypasses_pit:
		collision_mask &= ~(1 << (10 - 1)) # Clear pit mask (layer 10)

func _end_dash() -> void:
	is_dashing = false
	dash_ticks_left = 0
	if dash_bypasses_pit and not mediums.has("hover"):
		collision_mask |= (1 << (10 - 1)) # Restore pit mask
		if current_room != null:
			var t: Dictionary = current_room.terrain_at(global_position)
			if str(t.get("medium", "")) == "void":
				# Machine ended dash over void: falls/crashes
				state.take_damage(state.current_integrity, "void", true)

func _handle_slide_collision(col: KinematicCollision2D, delta: float) -> void:
	if col == null:
		return
	var collider_obj: Object = col.get_collider()
	if collider_obj == null:
		return
	var normal: Vector2 = col.get_normal()
	var push_dir: Vector2 = -normal

	if collider_obj is Machine:
		var target_machine: Machine = collider_obj as Machine
		if self.weight > target_machine.weight:
			var push_amt: Vector2 = push_dir * (self.velocity.length() * delta)
			target_machine.move_and_collide(push_amt)
	elif collider_obj is CharacterBody2D:
		var target_weight: int = int(collider_obj.get("weight"))
		if self.weight >= target_weight and self.weight > 0:
			var push_amt: Vector2 = push_dir * (self.velocity.length() * delta)
			(collider_obj as CharacterBody2D).move_and_collide(push_amt)

	if dash_breaks_cracked and current_room != null:
		var hit_pos: Vector2 = col.get_position() - normal * 4.0
		if current_room.has_method("break_tile_at"):
			current_room.call("break_tile_at", hit_pos, "ram")

## Called once per tick by World movement system
func step_movement(delta: float) -> void:
	if not state.can_act():
		if is_dashing:
			_end_dash()
		velocity = Vector2.ZERO
		return

	if is_dashing:
		dash_ticks_left -= 1
		velocity = dash_direction * dash_speed_px
		if Engine.is_in_physics_frame():
			move_and_slide()
			for i: int in range(get_slide_collision_count()):
				_handle_slide_collision(get_slide_collision(i), delta)
		else:
			var motion: Vector2 = velocity * delta
			var col: KinematicCollision2D = move_and_collide(motion)
			if col != null:
				_handle_slide_collision(col, delta)
				var remainder: Vector2 = col.get_remainder().slide(col.get_normal())
				move_and_collide(remainder)
		if dash_ticks_left <= 0:
			_end_dash()
		return

	if base_speed_tiles <= 0.0:
		# Sentry / stationary bodies don't move
		velocity = Vector2.ZERO
		return

	var speed_px: float = base_speed_tiles * float(Grid.TILE_SIZE)

	# Check terrain medium at current position
	if current_room != null:
		var terrain: Dictionary = current_room.terrain_at(global_position)
		var medium_type: String = str(terrain.get("medium", ""))
		if medium_type == "liquid" and not mediums.has("liquid"):
			speed_px *= 0.5 # Coolant slows non-swimmers

	velocity = current_intent.move * speed_px
	if Engine.is_in_physics_frame():
		move_and_slide()
		for i: int in range(get_slide_collision_count()):
			_handle_slide_collision(get_slide_collision(i), delta)
	else:
		var motion: Vector2 = velocity * delta
		var col: KinematicCollision2D = move_and_collide(motion)
		if col != null:
			_handle_slide_collision(col, delta)
			var remainder: Vector2 = col.get_remainder().slide(col.get_normal())
			move_and_collide(remainder)
