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

# Debug tooling state
var sim_duration_ms: float = 0.0
var show_debug_collisions: bool = false
var show_perf_overlay: bool = false
var is_recording_input: bool = false
var recorded_input_stream: Array[Dictionary] = []

@onready var room_container: Node2D = $RoomContainer
@onready var entities_container: Node2D = $Entities
@onready var hud_label: Label = $HUD/HUDLabel
@onready var perf_overlay: Control = $PerfOverlay
@onready var perf_label: Label = $PerfOverlay/PerfLabel
@onready var warp_dialog: Control = $WarpDialog
@onready var warp_input: LineEdit = $WarpDialog/LineEdit

func _ready() -> void:
	if active_room == null and current_room_id != "":
		load_room(current_room_id)
	if warp_input != null:
		warp_input.text_submitted.connect(_on_warp_submitted)

func _physics_process(delta: float) -> void:
	# 1. Sample manual player input via InputRouter (zero out if warp dialog is open)
	var input_router: Node = get_node_or_null("/root/InputRouter")
	if input_router != null:
		if warp_dialog != null and warp_dialog.visible:
			if input_router.has_method("reset_input"):
				input_router.call("reset_input")
		elif input_router.has_method("sample_input"):
			input_router.call("sample_input")

	if is_transitioning:
		_step_transition(delta)
		return

	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null and game_node.get("paused") == true:
		return

	var t0: int = Time.get_ticks_usec()
	if game_node != null and game_node.has_method("advance_tick"):
		game_node.call("advance_tick")
		tick_count = int(game_node.get("tick"))
	else:
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

	sim_duration_ms = float(Time.get_ticks_usec() - t0) / 1000.0

	_record_input_tick()
	_update_hud()
	_update_perf_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F2:
			toggle_debug_collisions()
		KEY_F3:
			toggle_perf_overlay()
		KEY_F6:
			toggle_warp_dialog()
		KEY_F10:
			toggle_input_recording()

func toggle_debug_collisions() -> void:
	show_debug_collisions = not show_debug_collisions
	# Toggle engine debug collisions hint
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.debug_collisions_hint = show_debug_collisions

func toggle_perf_overlay() -> void:
	show_perf_overlay = not show_perf_overlay
	if perf_overlay != null:
		perf_overlay.visible = show_perf_overlay

func toggle_warp_dialog() -> void:
	if warp_dialog == null:
		return
	warp_dialog.visible = not warp_dialog.visible
	if warp_dialog.visible:
		if warp_input != null:
			warp_input.grab_focus()
			warp_input.text = current_room_id

func _on_warp_submitted(new_room: String) -> void:
	var target: String = new_room.strip_edges()
	if target != "" and target != current_room_id:
		load_room(target)
	if warp_dialog != null:
		warp_dialog.visible = false

func toggle_input_recording() -> void:
	is_recording_input = not is_recording_input
	if not is_recording_input:
		save_input_recording()
	_update_hud()

func save_input_recording() -> void:
	var file: FileAccess = FileAccess.open("user://input_record.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(recorded_input_stream, "\t"))
		print("World: Input recording saved (%d ticks) to user://input_record.json" % recorded_input_stream.size())

func _record_input_tick() -> void:
	if not is_recording_input or player_machine == null or not is_instance_valid(player_machine):
		return
	var intent: Intent = player_machine.current_intent
	recorded_input_stream.append({
		"tick": tick_count,
		"room": current_room_id,
		"move": [intent.move.x, intent.move.y],
		"primary": intent.primary,
		"secondary": intent.secondary,
		"hop": intent.hop,
		"eject": intent.eject
	})

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

	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null:
		game_node.set("is_transitioning", true)

	var events_node: Node = get_node_or_null("/root/Events")
	if events_node != null:
		events_node.emit_signal("room_transition_started", current_room_id, next_room_id, Vector2i(int(dir.x), int(dir.y)))

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
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null:
		game_node.set("is_transitioning", false)
		game_node.set("current_room_id", current_room_id)

	var events_node: Node = get_node_or_null("/root/Events")
	if events_node != null:
		events_node.emit_signal("room_transition_finished", current_room_id)

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

	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null:
		game_node.set("current_room_id", current_room_id)

	var events_node: Node = get_node_or_null("/root/Events")
	if events_node != null:
		events_node.emit_signal("room_transition_finished", current_room_id)

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
	var rec_str: String = ""
	if is_recording_input:
		rec_str = " | REC: ON"
	hud_label.text = "TICK: %06d | ROOM: %s | SIZE: %s%s" % [tick_count, current_room_id, size_str, rec_str]

func _update_perf_overlay() -> void:
	if perf_label == null or not show_perf_overlay:
		return
	var fps: int = Engine.get_frames_per_second()
	perf_label.text = "FPS: %d | SIM: %.2f ms | ACTIVE: %d" % [fps, sim_duration_ms, machines.size()]
