class_name World
extends Node2D

signal room_entered(room_id: String)
signal room_transition_started(from_room: String, to_room: String)

const TRANSITION_DURATION: float = 0.3
const ROOM_PIXEL_SIZE: Vector2 = Vector2(480.0, 240.0)

var current_room_id: String = ""
var tick_count: int = 0
var is_transitioning: bool = false
var transition_time: float = 0.0
var transition_dir: Vector2 = Vector2.ZERO
var machine_slide_start: Vector2 = Vector2.ZERO
var machine_slide_target: Vector2 = Vector2.ZERO

var active_room: RoomRuntime = null
var incoming_room: RoomRuntime = null
var player_machine: Machine = null
var machines: Array[Machine] = []

@onready var room_container: Node2D = $RoomContainer
@onready var entities_container: Node2D = $Entities
@onready var hud_label: Label = $HUD/HUDLabel

func _ready() -> void:
	if active_room == null and current_room_id != "":
		load_room(current_room_id)

func _physics_process(delta: float) -> void:
	if is_transitioning:
		_step_transition(delta)
		return

	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null and game_node.get("paused") == true:
		return

	tick_count += 1

	# System 1: senses (P3+)
	# System 2: controllers
	_step_controllers(tick_count)
	# System 3: hijack (P3)
	# System 4: abilities (P4)
	# System 5: movement
	_step_movement(delta)
	# System 6: logic (P5)
	# System 7: combat (P9)
	# System 8: world (room transitions)
	_step_world()
	# System 9: cleanup
	_step_cleanup()

	_update_hud()

func _step_controllers(tick: int) -> void:
	for m: Machine in machines:
		if is_instance_valid(m):
			m.step_controller(tick)

func _step_movement(delta: float) -> void:
	for m: Machine in machines:
		if is_instance_valid(m):
			m.step_movement(delta)

func _step_world() -> void:
	if player_machine == null or not is_instance_valid(player_machine):
		return

	var pos: Vector2 = player_machine.position
	if pos.x >= ROOM_PIXEL_SIZE.x and active_room != null and active_room.exits.has("e"):
		start_transition(str(active_room.exits["e"]), Vector2(1, 0))
	elif pos.x < 0.0 and active_room != null and active_room.exits.has("w"):
		start_transition(str(active_room.exits["w"]), Vector2(-1, 0))
	elif pos.y >= ROOM_PIXEL_SIZE.y and active_room != null and active_room.exits.has("s"):
		start_transition(str(active_room.exits["s"]), Vector2(0, 1))
	elif pos.y < 0.0 and active_room != null and active_room.exits.has("n"):
		start_transition(str(active_room.exits["n"]), Vector2(0, -1))

func _step_cleanup() -> void:
	for i: int in range(machines.size() - 1, -1, -1):
		if not is_instance_valid(machines[i]):
			machines.remove_at(i)

func start_transition(next_room_id: String, dir: Vector2) -> void:
	if is_transitioning:
		return

	var room_path: String = WorldGrid.find_room_path(next_room_id)
	if room_path == "":
		printerr("World: Next room not found: " + next_room_id)
		return

	var data: Dictionary = RoomLoader.load_room(room_path)
	if data.is_empty():
		printerr("World: Failed to load room data: " + room_path)
		return

	incoming_room = RoomRuntime.new()
	incoming_room.name = "IncomingRoom"
	room_container.add_child(incoming_room)
	incoming_room.setup(data)
	incoming_room.position = dir * ROOM_PIXEL_SIZE

	is_transitioning = true
	transition_time = 0.0
	transition_dir = dir

	# Calculate machine slide positions across screen border
	machine_slide_start = player_machine.position
	machine_slide_target = machine_slide_start - (dir * ROOM_PIXEL_SIZE)
	# Clamp machine landing position inside doorway
	if dir.x > 0:
		machine_slide_target.x = 8.0
	elif dir.x < 0:
		machine_slide_target.x = ROOM_PIXEL_SIZE.x - 8.0
	elif dir.y > 0:
		machine_slide_target.y = 8.0
	elif dir.y < 0:
		machine_slide_target.y = ROOM_PIXEL_SIZE.y - 8.0

	room_transition_started.emit(current_room_id, next_room_id)

func _step_transition(delta: float) -> void:
	transition_time += delta
	var t: float = clampf(transition_time / TRANSITION_DURATION, 0.0, 1.0)

	if active_room != null:
		active_room.position = -transition_dir * ROOM_PIXEL_SIZE * t
	if incoming_room != null:
		incoming_room.position = transition_dir * ROOM_PIXEL_SIZE * (1.0 - t)
	if player_machine != null and is_instance_valid(player_machine):
		player_machine.position = machine_slide_start.lerp(machine_slide_target, t)

	if t >= 1.0:
		_finish_transition()

func _finish_transition() -> void:
	if active_room != null:
		room_container.remove_child(active_room)
		active_room.free()
	active_room = incoming_room
	incoming_room = null
	if active_room != null:
		active_room.name = "ActiveRoom"
		active_room.position = Vector2.ZERO
		current_room_id = active_room.room_id

	if player_machine != null and is_instance_valid(player_machine):
		player_machine.position = machine_slide_target
		player_machine.current_room = active_room

	is_transitioning = false
	_update_hud()
	room_entered.emit(current_room_id)

func load_room(room_id: String) -> void:
	current_room_id = room_id
	var room_path: String = WorldGrid.find_room_path(room_id)
	if room_path == "":
		printerr("World: Room not found: " + room_id)
		return

	var data: Dictionary = RoomLoader.load_room(room_path)
	if data.is_empty():
		printerr("World: Cannot load room: " + room_path)
		return

	if active_room != null:
		room_container.remove_child(active_room)
		active_room.free()
	if incoming_room != null:
		room_container.remove_child(incoming_room)
		incoming_room.free()
		incoming_room = null

	active_room = RoomRuntime.new()
	active_room.name = "ActiveRoom"
	room_container.add_child(active_room)
	active_room.setup(data)
	active_room.position = Vector2.ZERO

	_setup_player_machine(data)
	_update_hud()
	room_entered.emit(current_room_id)

func _setup_player_machine(room_data: Dictionary) -> void:
	if player_machine == null:
		var scene: PackedScene = load("res://scenes/machine.tscn")
		player_machine = scene.instantiate() as Machine
		entities_container.add_child(player_machine)
		machines.append(player_machine)

	player_machine.current_room = active_room

	# Find spawn position from entities
	var spawn_pos: Vector2 = Vector2(56.0, 120.0)
	var entities: Array = room_data.get("entities", [])
	for ent_variant: Variant in entities:
		if ent_variant is Dictionary:
			var ent: Dictionary = ent_variant as Dictionary
			if ent.get("kind", "") == "spawn_cursor":
				var at: Array = ent.get("at", [3, 7])
				if at.size() >= 2:
					spawn_pos = Vector2(float(at[0]) * 16.0 + 8.0, float(at[1]) * 16.0 + 8.0)
				break
	player_machine.position = spawn_pos

func _update_hud() -> void:
	if hud_label == null:
		return
	var size_str: String = "XS"
	if player_machine != null and is_instance_valid(player_machine):
		size_str = player_machine.size_class.to_upper()
	hud_label.text = "TICK: %06d | ROOM: %s | SIZE: %s" % [tick_count, current_room_id, size_str]
