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
var crates: Array[Crate] = []
var projectiles: Array[Projectile] = []
var room_links: Array[Dictionary] = []

var hijack_fsm: HijackFSM = HijackFSM.new()

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
	if hijack_fsm != null:
		hijack_fsm.state_changed.connect(_on_hijack_state_changed)
		hijack_fsm.host_parked.connect(_on_host_parked)
		hijack_fsm.host_seized.connect(_on_host_seized)
		hijack_fsm.ejected.connect(_on_host_ejected)
		hijack_fsm.node_seized.connect(_on_node_seized)
		hijack_fsm.node_exited.connect(_on_node_exited)
		hijack_fsm.transit_blocked_by_firewall.connect(_on_transit_blocked_by_firewall)
		hijack_fsm.reboot_triggered.connect(_on_reboot_triggered)
		hijack_fsm.model_registered.connect(_on_model_registered)
	if entities_container != null:
		entities_container.child_entered_tree.connect(_on_entity_child_entered)
		entities_container.child_exiting_tree.connect(_on_entity_child_exiting)
	if active_room == null and current_room_id != "":
		load_room(current_room_id)
	if warp_input != null:
		warp_input.text_submitted.connect(_on_warp_submitted)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if hijack_fsm != null and hijack_fsm.state == HijackFSM.State.TARGETING:
		hijack_fsm.cancel_targeting()

func handle_back_input() -> bool:
	if warp_dialog != null and warp_dialog.visible:
		warp_dialog.visible = false
		return true
	if hijack_fsm != null and hijack_fsm.state == HijackFSM.State.TARGETING:
		hijack_fsm.cancel_targeting()
		return true
	if hijack_fsm != null and hijack_fsm.state == HijackFSM.State.NODE_PILOT:
		var pos: Vector2 = player_machine.position if player_machine != null else Vector2.ZERO
		hijack_fsm.voluntary_eject(pos)
		return true
	return false

func _on_entity_child_entered(node: Node) -> void:
	if node is Crate:
		var c: Crate = node as Crate
		if not crates.has(c):
			crates.append(c)
	elif node is Projectile:
		var p: Projectile = node as Projectile
		if not projectiles.has(p):
			projectiles.append(p)

func _on_entity_child_exiting(node: Node) -> void:
	if node is Machine:
		machines.erase(node)
	elif node is Crate:
		crates.erase(node)
	elif node is Projectile:
		projectiles.erase(node)

func register_machine(m: Machine) -> void:
	if not machines.has(m):
		machines.append(m)

func register_crate(c: Crate) -> void:
	if not crates.has(c):
		crates.append(c)

func register_projectile(p: Projectile) -> void:
	if not projectiles.has(p):
		projectiles.append(p)

func _process(_delta: float) -> void:
	if hijack_fsm != null and (hijack_fsm.state == HijackFSM.State.TARGETING or hijack_fsm.state == HijackFSM.State.TRANSIT):
		queue_redraw()
	elif player_machine != null and player_machine.pin_position != Vector2.ZERO:
		queue_redraw()

func _draw() -> void:
	if hijack_fsm == null:
		return

	if hijack_fsm.state == HijackFSM.State.TARGETING:
		# Draw link range radius
		draw_arc(hijack_fsm.spark_pos, hijack_fsm.link_range_px, 0.0, TAU, 32, Color(0.2, 0.8, 1.0, 0.15), 1.0)
		for cand: Dictionary in hijack_fsm.targeting_candidates:
			var c_pos: Vector2 = cand.get("pos", Vector2.ZERO)
			var c_id: String = str(cand.get("id", ""))
			if c_id == hijack_fsm.selected_target_id:
				draw_line(hijack_fsm.spark_pos, c_pos, Color(0.2, 1.0, 0.8, 0.8), 1.5)
				draw_rect(Rect2(c_pos - Vector2(10, 10), Vector2(20, 20)), Color(0.2, 1.0, 0.8, 0.9), false, 1.5)
			else:
				draw_rect(Rect2(c_pos - Vector2(8, 8), Vector2(16, 16)), Color(0.2, 0.8, 1.0, 0.3), false, 1.0)

	elif hijack_fsm.state == HijackFSM.State.TRANSIT:
		draw_line(hijack_fsm.spark_pos, hijack_fsm.transit_target_pos, Color(0.3, 1.0, 0.9, 0.4), 1.0)
		draw_circle(hijack_fsm.spark_pos, 4.0, Color(0.8, 1.0, 0.9, 1.0))

	if player_machine != null and is_instance_valid(player_machine) and player_machine.pin_position != Vector2.ZERO:
		draw_circle(player_machine.pin_position, 3.0, Color(1.0, 0.8, 0.2, 0.7))

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
	_step_hijack(delta)
	# System 4: abilities
	_step_abilities(tick_count)
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
		KEY_F8:
			cycle_player_body()
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

const BODY_CYCLE_ORDER: Array[String] = [
	"cursor", "janitor", "loader", "sentry", "drone",
	"welder", "diver", "crawler", "courier", "medic"
]

func cycle_player_body() -> void:
	if player_machine == null or not is_instance_valid(player_machine):
		return
	var current_idx: int = BODY_CYCLE_ORDER.find(player_machine.body_id.to_lower())
	var next_idx: int = (current_idx + 1) % BODY_CYCLE_ORDER.size()
	var next_body_id: String = BODY_CYCLE_ORDER[next_idx]
	
	var data_node: Node = get_node_or_null("/root/Data")
	var body_dict: Dictionary = {}
	if data_node != null and data_node.has_method("get_json"):
		var raw: Variant = data_node.call("get_json", "res://data/bodies/%s.json" % next_body_id)
		if raw is Dictionary:
			body_dict = raw
	elif FileAccess.file_exists("res://data/bodies/%s.json" % next_body_id):
		var file: FileAccess = FileAccess.open("res://data/bodies/%s.json" % next_body_id, FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				body_dict = json.data as Dictionary
				
	if not body_dict.is_empty():
		player_machine.apply_body_data(body_dict)
		_update_hud()
		print("World: Swapped player body to: %s (%s)" % [player_machine.body_id, player_machine.size_class.to_upper()])

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
	if hijack_fsm != null and (hijack_fsm.state == HijackFSM.State.TARGETING or hijack_fsm.state == HijackFSM.State.TRANSIT):
		if player_machine != null and is_instance_valid(player_machine):
			player_machine.current_intent.move = Vector2.ZERO

func _step_hijack(delta: float) -> void:
	if player_machine == null or not is_instance_valid(player_machine):
		return

	# Handle routine cycling and pin dropping from player intent
	if player_machine.current_intent.routine_cycle:
		hijack_fsm.cycle_routine()
	if player_machine.current_intent.pin:
		hijack_fsm.drop_pin(player_machine.position, player_machine.facing)

	# Forced ejection check if currently hosted
	if hijack_fsm.state == HijackFSM.State.HOSTED:
		if player_machine.state != null:
			if player_machine.state.is_crashed:
				hijack_fsm.force_eject(player_machine.position, "crashed")
				return
			elif player_machine.state.is_overheated:
				hijack_fsm.force_eject(player_machine.position, "overheated")
				return

	# Voluntary ejection check
	if player_machine.current_intent.eject:
		if hijack_fsm.state == HijackFSM.State.HOSTED or hijack_fsm.state == HijackFSM.State.NODE_PILOT:
			hijack_fsm.voluntary_eject(player_machine.position, player_machine.facing)
			return

	# Start targeting check
	if player_machine.current_intent.hop and hijack_fsm.state != HijackFSM.State.TARGETING and hijack_fsm.state != HijackFSM.State.TRANSIT:
		var candidates: Array[Dictionary] = _get_hijack_candidates(player_machine.position)
		var aim_vec: Vector2 = player_machine.current_intent.aim
		if aim_vec == Vector2.ZERO:
			aim_vec = player_machine.facing
		hijack_fsm.start_targeting(player_machine.position, candidates, aim_vec)
		return

	# Targeting stepping
	if hijack_fsm.state == HijackFSM.State.TARGETING:
		var aim_vec: Vector2 = player_machine.current_intent.aim
		if aim_vec == Vector2.ZERO:
			aim_vec = player_machine.current_intent.move
		var confirm_pressed: bool = player_machine.current_intent.hop or player_machine.current_intent.primary
		var cancel_pressed: bool = player_machine.current_intent.secondary or Input.is_action_just_pressed("back")
		hijack_fsm.step_targeting_tick(aim_vec, confirm_pressed, cancel_pressed, player_machine.position, player_machine.facing)
		return

	# Transit stepping
	if hijack_fsm.state == HijackFSM.State.TRANSIT:
		var step_dist: float = HijackFSM.TRANSIT_SPEED_PX * delta
		var next_pos: Vector2 = hijack_fsm.spark_pos.move_toward(hijack_fsm.transit_target_pos, step_dist)
		var firewall_hit: Variant = check_transit_firewall(hijack_fsm.spark_pos, next_pos)
		hijack_fsm.step_transit(delta, firewall_hit)
		return

	# Node pilot stepping
	if hijack_fsm.state == HijackFSM.State.NODE_PILOT:
		if player_machine != null and is_instance_valid(player_machine):
			if player_machine.current_intent.primary or player_machine.current_intent.interact:
				var node_ent: Node = _find_entity_by_id(hijack_fsm.current_node_id)
				if node_ent != null and node_ent is InfraNode:
					(node_ent as InfraNode).operate_node()
			if player_machine.current_intent.hop or player_machine.current_intent.eject:
				var node_ent: Node = _find_entity_by_id(hijack_fsm.current_node_id)
				var pos: Vector2 = (node_ent as Node2D).position if node_ent is Node2D else player_machine.position
				hijack_fsm.voluntary_eject(pos)
				return
		return

	# Cursor TTL stepping and crash check
	if hijack_fsm.state == HijackFSM.State.CURSOR:
		if player_machine != null and player_machine.state != null and player_machine.state.is_crashed:
			hijack_fsm.reboot_triggered.emit("cursor_destroyed")
			return
		var is_safe: bool = is_pos_in_safe_zone(player_machine.position)
		hijack_fsm.step_cursor_ttl(is_safe, 1)

func _on_hijack_state_changed(old_state: int, new_state: int) -> void:
	if new_state == HijackFSM.State.TARGETING:
		Engine.time_scale = HijackFSM.TARGETING_TIME_SCALE
	elif old_state == HijackFSM.State.TARGETING:
		Engine.time_scale = 1.0

func _on_host_parked(host_id: String, routine: String, pin_pos: Vector2) -> void:
	var host: Machine = _find_machine_by_id(host_id)
	if host != null:
		host.operational_state = "parked"
		host.parked_routine = routine
		host.pin_position = pin_pos
		host.set_meta("parked_tick", tick_count)
		var p_state: ParkedState = ParkedState.new(routine, host.position, pin_pos, host.facing)
		var r_ctrl: RoutineController = RoutineController.new(p_state)
		r_ctrl.name = "Controller"
		var old_ctrl: Node = host.get_node_or_null("Controller")
		if old_ctrl != null:
			host.remove_child(old_ctrl)
			old_ctrl.queue_free()
		host.add_child(r_ctrl)
		host.controller = r_ctrl

func _on_host_seized(host_id: String, _model_id: String) -> void:
	var target: Machine = _find_machine_by_id(host_id)
	if target != null:
		if player_machine != null and player_machine != target:
			if player_machine.body_id == "cursor":
				var old_cursor: Machine = player_machine
				machines.erase(old_cursor)
				if is_instance_valid(old_cursor):
					old_cursor.queue_free()
		player_machine = target
		target.operational_state = "player"
		var p_ctrl: PlayerController = PlayerController.new()
		p_ctrl.name = "Controller"
		var old_ctrl: Node = target.get_node_or_null("Controller")
		if old_ctrl != null:
			target.remove_child(old_ctrl)
			old_ctrl.queue_free()
		target.add_child(p_ctrl)
		target.controller = p_ctrl
		_update_hud()

func _on_host_ejected(_from_id: String, _reason: String) -> void:
	_spawn_player_cursor_at(hijack_fsm.spark_pos)

func _on_transit_blocked_by_firewall(block_pos: Vector2) -> void:
	_spawn_player_cursor_at(block_pos)

func _on_node_seized(node_id: String) -> void:
	var ent: Node = _find_entity_by_id(node_id)
	if ent != null and ent is InfraNode:
		(ent as InfraNode).on_seized(self)

func _on_node_exited(node_id: String) -> void:
	var ent: Node = _find_entity_by_id(node_id)
	if ent != null and ent is InfraNode:
		(ent as InfraNode).on_exited()

func _on_reboot_triggered(reason: String) -> void:
	var events_node: Node = get_node_or_null("/root/Events")
	if events_node != null:
		events_node.emit_signal("reboot_triggered", reason)

	var game_node: Node = get_node_or_null("/root/Game")
	var target_room: String = current_room_id
	var has_dock: bool = false
	var dock_pos: Vector2 = Vector2.ZERO
	if game_node != null:
		var last_dock: String = str(game_node.get("last_dock_room_id"))
		if not last_dock.is_empty():
			target_room = last_dock
			has_dock = true
			dock_pos = game_node.get("last_dock_spawn_pos") as Vector2

	load_room(target_room)
	if has_dock and dock_pos != Vector2.ZERO and player_machine != null:
		player_machine.position = dock_pos
	hijack_fsm.refill_ttl()

func _on_model_registered(model_id: String) -> void:
	var events_node: Node = get_node_or_null("/root/Events")
	if events_node != null:
		events_node.emit_signal("log_found", "reg_%s" % model_id)

func _save_current_room_parked_hosts() -> void:
	if current_room_id == "":
		return
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node == null:
		return
	var p_hosts: Dictionary = game_node.get("persistent_parked_hosts")
	var room_records: Array = []
	for m: Machine in machines:
		if not is_instance_valid(m) or m == player_machine:
			continue
		if m.operational_state == "parked":
			room_records.append({
				"id": m.entity_id,
				"model": m.body_id,
				"pos": [m.position.x, m.position.y],
				"facing": [m.facing.x, m.facing.y],
				"routine": m.parked_routine,
				"pin_pos": [m.pin_position.x, m.pin_position.y],
				"integrity": m.state.current_integrity if m.state != null else 10,
				"heat": m.state.current_heat if m.state != null else 0.0,
				"is_holding_latch": bool(m.get_meta("is_holding_latch", false)),
				"parked_tick": int(m.get_meta("parked_tick", tick_count))
			})
	if room_records.is_empty():
		p_hosts.erase(current_room_id)
	else:
		p_hosts[current_room_id] = room_records
	_enforce_garage_slots_cap()

func _restore_current_room_parked_hosts() -> void:
	if current_room_id == "":
		return
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node == null:
		return
	var p_hosts: Dictionary = game_node.get("persistent_parked_hosts")
	if not p_hosts.has(current_room_id):
		return
	var records: Array = p_hosts[current_room_id]
	for rec_val: Variant in records:
		if not (rec_val is Dictionary):
			continue
		var rec: Dictionary = rec_val as Dictionary
		var hid: String = str(rec.get("id", ""))
		if _find_machine_by_id(hid) != null:
			continue
		var model_id: String = str(rec.get("model", "janitor"))
		var pos_arr: Array = rec.get("pos", [0, 0])
		var spawn_pos: Vector2 = Vector2(float(pos_arr[0]), float(pos_arr[1]))

		var scene: PackedScene = load("res://scenes/machine.tscn")
		if scene == null:
			continue
		var m: Machine = scene.instantiate() as Machine
		m.entity_id = hid
		m.position = spawn_pos
		m.current_room = active_room
		m.operational_state = "parked"
		m.parked_routine = str(rec.get("routine", "hold"))
		var pin_arr: Array = rec.get("pin_pos", [spawn_pos.x, spawn_pos.y])
		m.pin_position = Vector2(float(pin_arr[0]), float(pin_arr[1]))
		m.set_meta("is_holding_latch", bool(rec.get("is_holding_latch", false)))
		m.set_meta("parked_tick", int(rec.get("parked_tick", tick_count)))

		var facing_arr: Array = rec.get("facing", [0, 1])
		m.facing = Vector2(float(facing_arr[0]), float(facing_arr[1]))

		entities_container.add_child(m)
		register_machine(m)

		var data_node: Node = get_node_or_null("/root/Data")
		var b_dict: Dictionary = {}
		if data_node != null and data_node.has_method("get_json"):
			var raw: Variant = data_node.call("get_json", "res://data/bodies/%s.json" % model_id)
			if raw is Dictionary:
				b_dict = raw
		elif FileAccess.file_exists("res://data/bodies/%s.json" % model_id):
			var file: FileAccess = FileAccess.open("res://data/bodies/%s.json" % model_id, FileAccess.READ)
			if file != null:
				var json: JSON = JSON.new()
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					b_dict = json.data as Dictionary
		if not b_dict.is_empty():
			m.apply_body_data(b_dict)

		if m.state != null:
			m.state.current_integrity = int(rec.get("integrity", m.state.max_integrity))
			m.state.current_heat = float(rec.get("heat", 0.0))

		var p_state: ParkedState = ParkedState.new(m.parked_routine, spawn_pos, m.pin_position, m.facing)
		var r_ctrl: RoutineController = RoutineController.new(p_state)
		r_ctrl.name = "Controller"
		var old_ctrl: Node = m.get_node_or_null("Controller")
		if old_ctrl != null:
			m.remove_child(old_ctrl)
			old_ctrl.queue_free()
		m.add_child(r_ctrl)
		m.controller = r_ctrl

func _enforce_garage_slots_cap() -> void:
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node == null:
		return
	var p_hosts: Dictionary = game_node.get("persistent_parked_hosts")
	var cap: int = int(game_node.get("garage_slots_cap"))
	if cap <= 0:
		cap = 3

	var outside_hosts: Array[Dictionary] = []
	for r_id: String in p_hosts.keys():
		if r_id == current_room_id:
			continue
		var arr: Array = p_hosts[r_id]
		for host_dict: Variant in arr:
			if host_dict is Dictionary:
				var d: Dictionary = (host_dict as Dictionary).duplicate()
				d["_room_id"] = r_id
				outside_hosts.append(d)

	while outside_hosts.size() > cap:
		outside_hosts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("parked_tick", 0)) < int(b.get("parked_tick", 0))
		)

		var recycled_one: bool = false
		for i: int in range(outside_hosts.size()):
			var candidate: Dictionary = outside_hosts[i]
			if not bool(candidate.get("is_holding_latch", false)):
				var target_room: String = str(candidate.get("_room_id", ""))
				var target_id: String = str(candidate.get("id", ""))
				if p_hosts.has(target_room):
					var room_arr: Array = p_hosts[target_room]
					for j: int in range(room_arr.size() - 1, -1, -1):
						if str(room_arr[j].get("id", "")) == target_id:
							room_arr.remove_at(j)
							break
					if room_arr.is_empty():
						p_hosts.erase(target_room)

				outside_hosts.remove_at(i)
				var refund: int = 10
				var cur_scrap: int = int(game_node.get("scrap"))
				game_node.set("scrap", cur_scrap + refund)

				var events_node: Node = get_node_or_null("/root/Events")
				if events_node != null:
					events_node.emit_signal("host_recycled", target_id, refund)

				recycled_one = true
				break

		if not recycled_one:
			break

func _get_hijack_candidates(origin_pos: Vector2) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for m: Machine in machines:
		if not is_instance_valid(m) or m == player_machine:
			continue
		var cand_pos: Vector2 = m.position
		var has_los: bool = check_line_of_sight(origin_pos, cand_pos)
		candidates.append({
			"id": m.entity_id,
			"kind": "machine",
			"model": m.body_id,
			"state": m.operational_state,
			"is_open": m.is_open(),
			"pos": cand_pos,
			"clearance": m.clearance_level,
			"is_immune_unit": m.is_immune_unit,
			"is_boss_body": m.is_boss_body,
			"has_los": has_los
		})

	if is_inside_tree():
		for node_ent: Node in get_tree().get_nodes_in_group("infrastructure_nodes"):
			if node_ent is InfraNode and is_instance_valid(node_ent):
				var n: InfraNode = node_ent as InfraNode
				var has_los: bool = check_line_of_sight(origin_pos, n.position)
				candidates.append({
					"id": n.entity_id,
					"kind": "node",
					"model": "node",
					"state": "dormant",
					"is_open": true,
					"pos": n.position,
					"clearance": n.clearance_level,
					"is_immune_unit": false,
					"is_boss_body": false,
					"has_los": has_los
				})
	return candidates

func check_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	if not is_inside_tree() or get_world_2d() == null:
		return true
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return true
	var mask: int = (1 << 0) | (1 << 7) # Layer 1 (solid) | Layer 8 (firewall)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos, mask)
	var exclude: Array[RID] = []
	if player_machine != null and is_instance_valid(player_machine):
		exclude.append(player_machine.get_rid())
	for m: Machine in machines:
		if is_instance_valid(m):
			exclude.append(m.get_rid())
	query.exclude = exclude
	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()

func check_transit_firewall(from_pos: Vector2, to_pos: Vector2) -> Variant:
	if not is_inside_tree() or get_world_2d() == null:
		return null
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return null
	var mask: int = (1 << 7) # Layer 8 (firewall)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos, mask)
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.get("position", to_pos)
	return null

func is_pos_in_safe_zone(pixel_pos: Vector2) -> bool:
	if active_room != null:
		var cell: Vector2i = Grid.pixel_to_tile(pixel_pos)
		if Grid.is_in_room_bounds(cell) and cell.y < active_room.grid.size() and cell.x < active_room.grid[cell.y].length():
			var glyph: String = active_room.grid[cell.y][cell.x]
			if glyph == ":":
				return true
	if is_inside_tree() and player_machine != null:
		for dock: Node in get_tree().get_nodes_in_group("docks"):
			if dock is Area2D and (dock as Area2D).overlaps_body(player_machine):
				return true
		for inf_node: Node in get_tree().get_nodes_in_group("infrastructure_nodes"):
			if inf_node is Area2D and (inf_node as Area2D).overlaps_body(player_machine):
				return true
	return false

func _find_machine_by_id(id: String) -> Machine:
	for m: Machine in machines:
		if is_instance_valid(m) and m.entity_id == id:
			return m
	return null

func _find_entity_by_id(id: String) -> Node:
	for m: Machine in machines:
		if is_instance_valid(m) and m.entity_id == id:
			return m
	if entities_container != null:
		for child: Node in entities_container.get_children():
			if child.get("entity_id") == id:
				return child
	return null

func trigger_links(from_id: String, active: bool) -> void:
	for link: Dictionary in room_links:
		if str(link.get("from", "")) == from_id:
			var target_id: String = str(link.get("to", ""))
			var target_ent: Node = _find_entity_by_id(target_id)
			if target_ent != null:
				if target_ent is Door:
					(target_ent as Door).set_open(active)
				elif target_ent is Firewall:
					(target_ent as Firewall).set_active(not active)
				elif target_ent.has_method("set_active"):
					target_ent.call("set_active", not active)
				elif target_ent.has_method("set_open"):
					target_ent.call("set_open", active)

func _spawn_player_cursor_at(pos: Vector2) -> Machine:
	var scene: PackedScene = load("res://scenes/machine.tscn")
	if scene == null:
		return null
	var cursor_m: Machine = scene.instantiate() as Machine
	cursor_m.name = "PlayerCursor"
	cursor_m.entity_id = "player"
	cursor_m.position = pos
	cursor_m.current_room = active_room
	cursor_m.operational_state = "player"
	entities_container.add_child(cursor_m)
	register_machine(cursor_m)

	var data_node: Node = get_node_or_null("/root/Data")
	var cursor_dict: Dictionary = {}
	if data_node != null and data_node.has_method("get_json"):
		var raw: Variant = data_node.call("get_json", "res://data/bodies/cursor.json")
		if raw is Dictionary:
			cursor_dict = raw
	elif FileAccess.file_exists("res://data/bodies/cursor.json"):
		var file: FileAccess = FileAccess.open("res://data/bodies/cursor.json", FileAccess.READ)
		if file != null:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				cursor_dict = json.data as Dictionary
	if not cursor_dict.is_empty():
		cursor_m.apply_body_data(cursor_dict)

	var p_ctrl: PlayerController = PlayerController.new()
	p_ctrl.name = "Controller"
	var old_ctrl: Node = cursor_m.get_node_or_null("Controller")
	if old_ctrl != null:
		cursor_m.remove_child(old_ctrl)
		old_ctrl.queue_free()
	cursor_m.add_child(p_ctrl)
	cursor_m.controller = p_ctrl

	player_machine = cursor_m
	_update_hud()
	return cursor_m

func _step_abilities(tick: int) -> void:
	for m: Machine in machines:
		if is_instance_valid(m):
			m.step_abilities(tick)

func _step_movement(delta: float) -> void:
	for m: Machine in machines:
		if is_instance_valid(m):
			m.step_movement(delta)
	for c: Crate in crates:
		if is_instance_valid(c):
			c.step_movement(delta)
	for p: Projectile in projectiles:
		if is_instance_valid(p):
			p.step(delta)

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
	for i: int in range(crates.size() - 1, -1, -1):
		if not is_instance_valid(crates[i]):
			crates.remove_at(i)
	for i: int in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[i]):
			projectiles.remove_at(i)

func _clear_transient_projectiles() -> void:
	for p: Projectile in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()

func _clear_room_entities() -> void:
	_clear_transient_projectiles()
	if entities_container != null:
		for child: Node in entities_container.get_children():
			if child != player_machine and is_instance_valid(child):
				entities_container.remove_child(child)
				child.queue_free()
	machines.clear()
	if player_machine != null and is_instance_valid(player_machine):
		machines.append(player_machine)
	crates.clear()

func _spawn_room_entities(room_data: Dictionary) -> void:
	room_links.clear()
	var links_val: Variant = room_data.get("links", [])
	if links_val is Array:
		for l: Variant in links_val:
			if l is Dictionary:
				room_links.append((l as Dictionary).duplicate())

	var entities: Array = room_data.get("entities", [])
	for ent_variant: Variant in entities:
		if not (ent_variant is Dictionary):
			continue
		var ent: Dictionary = ent_variant as Dictionary
		var kind: String = str(ent.get("kind", ""))
		var at: Array = ent.get("at", [0, 0])
		var pos: Vector2 = Vector2(0, 0)
		if at.size() >= 2:
			pos = Vector2(float(at[0]) * 16.0 + 8.0, float(at[1]) * 16.0 + 8.0)

		if kind == "crate":
			var crate: Crate = Crate.new()
			crate.position = pos
			crate.weight = int(ent.get("weight", 1))
			crate.size_class = str(ent.get("size", "m"))
			entities_container.add_child(crate)
			if not crates.has(crate):
				crates.append(crate)
		elif kind == "dock":
			var dock: Dock = Dock.new()
			dock.entity_id = str(ent.get("id", "dock_01"))
			dock.position = pos
			entities_container.add_child(dock)
		elif kind == "door":
			var door: Door = Door.new()
			door.entity_id = str(ent.get("id", "door_01"))
			door.position = pos
			door.is_open = bool(ent.get("is_open", false))
			entities_container.add_child(door)
		elif kind == "plate":
			var plate: Plate = Plate.new()
			plate.entity_id = str(ent.get("id", "plate_01"))
			plate.position = pos
			plate.weight_threshold = int(ent.get("weight_threshold", 1))
			plate.is_latched = bool(ent.get("is_latched", false))
			entities_container.add_child(plate)
		elif kind == "firewall":
			var fw: Firewall = Firewall.new()
			fw.entity_id = str(ent.get("id", "firewall_01"))
			fw.position = pos
			fw.is_active = bool(ent.get("is_active", true))
			entities_container.add_child(fw)
		elif kind == "node":
			var inode: InfraNode = InfraNode.new()
			inode.entity_id = str(ent.get("id", "node_01"))
			inode.position = pos
			inode.clearance_level = int(ent.get("clearance", 0))
			entities_container.add_child(inode)
		elif kind == "machine":
			var machine_scene: PackedScene = load("res://scenes/machine.tscn")
			if machine_scene != null:
				var m: Machine = machine_scene.instantiate() as Machine
				var model_id: String = str(ent.get("model", "janitor"))
				m.position = pos
				m.current_room = active_room

				var ent_id: String = str(ent.get("id", ""))
				if ent_id != "":
					m.entity_id = ent_id
				else:
					m.entity_id = "%s_%d" % [model_id, machines.size()]
				var state_str: String = str(ent.get("state", "dormant"))
				m.operational_state = state_str
				if ent.has("clearance"):
					m.clearance_level = int(ent["clearance"])
				if ent.has("is_immune_unit"):
					m.is_immune_unit = bool(ent["is_immune_unit"])
				if ent.has("is_boss_body"):
					m.is_boss_body = bool(ent["is_boss_body"])

				if state_str == "dormant":
					var null_ctrl: NullController = NullController.new()
					null_ctrl.name = "Controller"
					var old_ctrl: Node = m.get_node_or_null("Controller")
					if old_ctrl != null:
						m.remove_child(old_ctrl)
						old_ctrl.queue_free()
					m.add_child(null_ctrl)
					m.controller = null_ctrl

				entities_container.add_child(m)
				if not machines.has(m):
					machines.append(m)

				var data_node: Node = get_node_or_null("/root/Data")
				var b_dict: Dictionary = {}
				if data_node != null and data_node.has_method("get_json"):
					var raw: Variant = data_node.call("get_json", "res://data/bodies/%s.json" % model_id)
					if raw is Dictionary:
						b_dict = raw
				elif FileAccess.file_exists("res://data/bodies/%s.json" % model_id):
					var file: FileAccess = FileAccess.open("res://data/bodies/%s.json" % model_id, FileAccess.READ)
					if file != null:
						var json: JSON = JSON.new()
						if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
							b_dict = json.data as Dictionary
				if not b_dict.is_empty():
					m.apply_body_data(b_dict)
				else:
					m.body_id = model_id

func start_transition(next_room_id: String, dir: Vector2) -> void:
	if is_transitioning:
		return
	_save_current_room_parked_hosts()
	_clear_transient_projectiles()

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

	_clear_room_entities()
	if active_room != null:
		var room_path: String = WorldGrid.find_room_path(current_room_id)
		if room_path != "":
			var r_data: Dictionary = RoomLoader.load_room(room_path)
			_spawn_room_entities(r_data)
			_restore_current_room_parked_hosts()

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
	Engine.time_scale = 1.0
	if current_room_id != "" and current_room_id != room_id:
		_save_current_room_parked_hosts()
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

	_clear_room_entities()
	_setup_player_machine(data)
	_spawn_room_entities(data)
	_restore_current_room_parked_hosts()
	var pause_ttl: bool = bool(data.get("pause_ttl_until_hijack", false))
	hijack_fsm.reset_for_room(pause_ttl)
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
		if not machines.has(player_machine):
			machines.append(player_machine)

		# Apply cursor.json body data on initial instantiation (Bug 4 fix)
		var data_node: Node = get_node_or_null("/root/Data")
		var cursor_dict: Dictionary = {}
		if data_node != null and data_node.has_method("get_json"):
			var raw: Variant = data_node.call("get_json", "res://data/bodies/cursor.json")
			if raw is Dictionary:
				cursor_dict = raw
		elif FileAccess.file_exists("res://data/bodies/cursor.json"):
			var file: FileAccess = FileAccess.open("res://data/bodies/cursor.json", FileAccess.READ)
			if file != null:
				var json: JSON = JSON.new()
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					cursor_dict = json.data as Dictionary
		if not cursor_dict.is_empty():
			player_machine.apply_body_data(cursor_dict)

	player_machine.current_room = active_room
	player_machine.entity_id = "player"
	player_machine.operational_state = "player"
	if player_machine.body_id == "cursor":
		hijack_fsm.state = HijackFSM.State.CURSOR
		hijack_fsm.current_host_id = ""
	else:
		hijack_fsm.state = HijackFSM.State.HOSTED
		hijack_fsm.current_host_id = "player"

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
	var body_name: String = "CURSOR"
	var hp_str: String = "02/02"
	var heat_str: String = "000/100"
	if player_machine != null and is_instance_valid(player_machine):
		size_str = player_machine.size_class.to_upper()
		body_name = player_machine.body_id.to_upper()
		if player_machine.state != null:
			hp_str = "%02d/%02d" % [player_machine.state.current_integrity, player_machine.state.max_integrity]
			heat_str = "%03d/%03d" % [int(round(player_machine.state.current_heat)), int(round(player_machine.state.max_heat))]
	var fsm_state_str: String = "CURSOR"
	if hijack_fsm != null:
		match hijack_fsm.state:
			HijackFSM.State.CURSOR:
				var ttl_sec: int = int(ceil(float(hijack_fsm.ttl_ticks) / 60.0))
				fsm_state_str = "CURSOR [TTL %02ds]" % ttl_sec
			HijackFSM.State.HOSTED:
				fsm_state_str = "HOSTED [%s]" % hijack_fsm.selected_routine.to_upper()
			HijackFSM.State.TARGETING:
				fsm_state_str = "AIMING"
			HijackFSM.State.TRANSIT:
				fsm_state_str = "TRANSIT"
			HijackFSM.State.NODE_PILOT:
				fsm_state_str = "NODE"
	var game_node: Node = get_node_or_null("/root/Game")
	var garage_count: int = 0
	if game_node != null:
		var reg: Variant = game_node.get("registered_models")
		if reg is Array:
			garage_count = (reg as Array).size()
	var rec_str: String = ""
	if is_recording_input:
		rec_str = " | REC: ON"
	hud_label.text = "TICK: %06d | ROOM: %s | %s | BODY: %s | HP: %s | HEAT: %s | SIZE: %s | GARAGE: %d/10%s" % [
		tick_count, current_room_id, fsm_state_str, body_name, hp_str, heat_str, size_str, garage_count, rec_str
	]

func _update_perf_overlay() -> void:
	if perf_label == null or not show_perf_overlay:
		return
	var fps: int = Engine.get_frames_per_second()
	perf_label.text = "FPS: %d | SIM: %.2f ms | ACTIVE: %d" % [fps, sim_duration_ms, machines.size()]
