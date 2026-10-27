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
var passives: Array[String] = []
var carried_object: CharacterBody2D = null

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_speed_px: float = 0.0
var dash_ticks_left: int = 0
var dash_breaks_cracked: bool = false
var dash_bypasses_pit: bool = false
var dash_damage: int = 0
var dash_knockback: float = 0.0
var dash_hit_machines: Array[Machine] = []
var knockback_velocity: Vector2 = Vector2.ZERO

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
	# Update visual feedback colors
	if visual_rect != null:
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

	# Redraw active ability geometry if any active ability or status is present
	var has_ability_visual: bool = false
	if abilities != null:
		if abilities.primary_slot.get("state") == "active" or abilities.secondary_slot.get("state") == "active":
			has_ability_visual = true
	if state != null and (state.has_status("ping_active") or state.has_status("bubble_shield")):
		has_ability_visual = true
	if has_ability_visual:
		queue_redraw()

func _draw() -> void:
	if abilities != null:
		if abilities.primary_slot.get("state") == "active":
			_draw_ability_effect(str(abilities.primary_data.get("kind", "")), abilities.primary_data, abilities.primary_slot.get("dir", facing))
		if abilities.secondary_slot.get("state") == "active":
			_draw_ability_effect(str(abilities.secondary_data.get("kind", "")), abilities.secondary_data, abilities.secondary_slot.get("dir", facing))

	if state != null:
		if state.has_status("ping_active"):
			draw_arc(Vector2.ZERO, 80.0, 0.0, TAU, 32, Color(0.1, 0.9, 1.0, 0.6), 1.5)
		if state.has_status("bubble_shield"):
			var b_radius: float = 14.0
			if collider != null and collider.shape != null:
				b_radius = collider.shape.get_rect().size.x * 0.75 + 4.0
			draw_arc(Vector2.ZERO, b_radius, 0.0, TAU, 24, Color(0.3, 0.8, 1.0, 0.85), 2.0)

func _draw_ability_effect(kind: String, _data: Dictionary, dir: Vector2) -> void:
	var dir_norm: Vector2 = dir.normalized() if dir != Vector2.ZERO else facing
	var angle_rad: float = dir_norm.angle()

	match kind:
		"melee_arc":
			var half_arc: float = deg_to_rad(45.0)
			var radius: float = 24.0
			draw_arc(Vector2.ZERO, radius, angle_rad - half_arc, angle_rad + half_arc, 16, Color(0.95, 0.75, 0.2, 0.9), 2.5)
			draw_line(Vector2.ZERO, dir_norm.rotated(-half_arc) * radius, Color(0.95, 0.75, 0.2, 0.6), 1.5)
			draw_line(Vector2.ZERO, dir_norm.rotated(half_arc) * radius, Color(0.95, 0.75, 0.2, 0.6), 1.5)
		"claw":
			var half_arc: float = deg_to_rad(30.0)
			var radius: float = 18.0
			draw_arc(Vector2.ZERO, radius, angle_rad - half_arc, angle_rad + half_arc, 12, Color(0.4, 0.9, 0.3, 0.9), 2.0)
			draw_line(Vector2.ZERO, dir_norm.rotated(-half_arc) * radius, Color(0.4, 0.9, 0.3, 0.6), 1.5)
			draw_line(Vector2.ZERO, dir_norm.rotated(half_arc) * radius, Color(0.4, 0.9, 0.3, 0.6), 1.5)
		"suction":
			draw_arc(Vector2.ZERO, 64.0, 0.0, TAU, 32, Color(0.9, 0.7, 0.2, 0.4), 1.5)
		"flame_cone":
			var half_cone: float = deg_to_rad(22.5)
			var length: float = 32.0
			draw_line(Vector2.ZERO, dir_norm.rotated(-half_cone) * length, Color(1.0, 0.45, 0.1, 0.8), 2.0)
			draw_line(Vector2.ZERO, dir_norm.rotated(half_cone) * length, Color(1.0, 0.45, 0.1, 0.8), 2.0)
			draw_arc(Vector2.ZERO, length, angle_rad - half_cone, angle_rad + half_cone, 12, Color(1.0, 0.55, 0.1, 0.9), 2.5)
		"beam_channel":
			var length: float = 64.0
			draw_line(Vector2.ZERO, dir_norm * length, Color(0.9, 0.6, 1.0, 0.9), 3.0)
			draw_line(Vector2.ZERO, dir_norm * length, Color(1.0, 1.0, 1.0, 1.0), 1.0)
		"repair_beam":
			var length: float = 48.0
			draw_line(Vector2.ZERO, dir_norm * length, Color(0.2, 1.0, 0.6, 0.9), 3.0)
			draw_line(Vector2.ZERO, dir_norm * length, Color(1.0, 1.0, 1.0, 1.0), 1.0)

func apply_knockback(impulse: Vector2) -> void:
	if passives.has("knockback_resist"):
		knockback_velocity += impulse * 0.25 # Reduced by 75%
	else:
		knockback_velocity += impulse

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
			
	var pass_val: Variant = data.get("passives", [])
	passives.clear()
	if pass_val is Array:
		for p: Variant in pass_val:
			passives.append(str(p))
			
	state.setup_from_dict(data)
	_apply_size_class()
	if abilities != null:
		abilities.setup(self, primary_ability, secondary_ability)

func take_damage(amount: int, damage_type: String = "kinetic", ignore_invuln: bool = false) -> bool:
	if damage_type == "thermal" and (passives.has("fire_immune") or body_id == "welder"):
		return false
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
	var data_node: Node = null
	if is_inside_tree():
		data_node = get_node_or_null("/root/Data")
	if data_node == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			var root_node: Window = (main_loop as SceneTree).root
			if root_node != null:
				data_node = root_node.get_node_or_null("Data")
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

func start_dash(dir: Vector2, speed_px: float, ticks: int, breaks_cracked: bool, bypasses_pit: bool, grant_invuln: bool, damage: int = 0, knockback: float = 0.0) -> void:
	is_dashing = true
	dash_direction = dir
	dash_speed_px = speed_px
	dash_ticks_left = ticks
	dash_breaks_cracked = breaks_cracked
	dash_bypasses_pit = bypasses_pit
	dash_damage = damage
	dash_knockback = knockback
	dash_hit_machines.clear()
	if grant_invuln and state != null:
		state.invulnerability_ticks = maxi(state.invulnerability_ticks, ticks)
	if bypasses_pit:
		collision_mask &= ~(1 << (10 - 1)) # Clear pit mask (layer 10)

func _end_dash() -> void:
	is_dashing = false
	dash_ticks_left = 0
	dash_damage = 0
	dash_knockback = 0.0
	dash_hit_machines.clear()
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
		if is_dashing and dash_damage > 0:
			if not dash_hit_machines.has(target_machine):
				dash_hit_machines.append(target_machine)
				target_machine.take_damage(dash_damage, "kinetic")
				var kb_vec: Vector2 = AbilityMath.calculate_knockback(global_position, target_machine.global_position, dash_knockback * float(Grid.TILE_SIZE))
				target_machine.apply_knockback(kb_vec)

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
		velocity = knockback_velocity
		if velocity != Vector2.ZERO:
			if Engine.is_in_physics_frame():
				move_and_slide()
			else:
				move_and_collide(velocity * delta)
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
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
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		return

	var effective_speed_tiles: float = base_speed_tiles
	if body_id == "diver":
		var in_liquid: bool = false
		if current_room != null:
			var t: Dictionary = current_room.terrain_at(global_position)
			in_liquid = (str(t.get("medium", "")) == "liquid")
		if not in_liquid:
			effective_speed_tiles = 2.4

	if effective_speed_tiles <= 0.0:
		# Sentry / stationary bodies don't move from intent, but can be knocked back
		velocity = knockback_velocity
		if velocity != Vector2.ZERO:
			if Engine.is_in_physics_frame():
				move_and_slide()
			else:
				move_and_collide(velocity * delta)
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		return

	var speed_px: float = effective_speed_tiles * float(Grid.TILE_SIZE)

	# Check terrain medium and hazards at current position
	if current_room != null:
		var terrain: Dictionary = current_room.terrain_at(global_position)
		var medium_type: String = str(terrain.get("medium", ""))
		var hazard_type: String = str(terrain.get("hazard", ""))

		# Medium: Liquid (Coolant)
		if medium_type == "liquid":
			if not mediums.has("liquid"):
				speed_px *= 0.5 # Coolant slows non-swimmers
				state.add_heat(15.0 * delta) # Non-divers take 15 Heat/s

		# Medium: Void (Pit) - Drone passive cooling
		if medium_type == "void" and mediums.has("hover"):
			state.current_heat = maxf(0.0, state.current_heat - (8.0 * delta)) # 8 Heat/s drain

		# Hazard: Spikes / Floor hazards
		if hazard_type == "spikes":
			if not (passives.has("insulated") or body_id == "crawler"):
				take_damage(1, "kinetic")

		# Hazard: Bitrot
		if hazard_type == "bitrot":
			if not (passives.has("bitrot_immune") or body_id == "janitor"):
				take_damage(1, "decay")

	velocity = current_intent.move * speed_px + knockback_velocity
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

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
