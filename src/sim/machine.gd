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
	else:
		current_intent.reset()
		
	# Update facing from move or aim
	if current_intent.aim != Vector2.ZERO:
		facing = AbilityMath.snap_to_8_way(current_intent.aim, facing)
	elif current_intent.move != Vector2.ZERO:
		facing = AbilityMath.snap_to_8_way(current_intent.move, facing)

## Called once per tick by World abilities system
func step_abilities(tick: int) -> void:
	if abilities != null:
		abilities.step(tick, current_intent)

## Called once per tick by World movement system
func step_movement(delta: float) -> void:
	if not state.can_act():
		velocity = Vector2.ZERO
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
	else:
		var motion: Vector2 = velocity * delta
		var col: KinematicCollision2D = move_and_collide(motion)
		if col != null:
			var remainder: Vector2 = col.get_remainder().slide(col.get_normal())
			move_and_collide(remainder)
