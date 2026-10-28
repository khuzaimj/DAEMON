class_name HijackFSM
extends RefCounted

enum State {
	CURSOR,
	HOSTED,
	TARGETING,
	TRANSIT,
	NODE_PILOT
}

signal state_changed(old_state: int, new_state: int)
signal targeting_started(valid_ids: Array[String], selected_id: String)
signal target_selected(selected_id: String)
signal targeting_cancelled()
signal transit_started(from_pos: Vector2, target_id: String, target_pos: Vector2)
signal transit_blocked_by_firewall(block_pos: Vector2)
signal host_seized(host_id: String, model_id: String)
signal node_seized(node_id: String)
signal node_exited(node_id: String)
signal host_parked(host_id: String, routine: String, pin_pos: Vector2)
signal ejected(from_id: String, reason: String)
signal model_registered(model_id: String)
signal routine_changed(new_routine: String)
signal pin_dropped(pin_pos: Vector2)
signal ttl_changed(current_ticks: int, max_ticks: int)
signal reboot_triggered(reason: String)

const BASE_TTL_TICKS: int = 480 # 8.0s at 60 TPS
const TTL_UPGRADE_TICKS: int = 180 # +3.0s per upgrade (max 4 upgrades -> 20.0s = 1200 ticks)
const MAX_TTL_CAP_TICKS: int = 1200
const TARGETING_MAX_TICKS: int = 60 # 1.0s max targeting window
const TARGETING_TIME_SCALE: float = 0.25
const TRANSIT_SPEED_TILES: float = 20.0
const TRANSIT_SPEED_PX: float = 320.0 # 20 tiles/s * 16 px
const BASE_LINK_RANGE_TILES: float = 5.0
const LINK_RANGE_UPGRADE_TILES: float = 2.0
const MAX_LINK_RANGE_TILES: float = 11.0
const ROUTINES: Array[String] = ["hold", "guard", "patrol", "repeat"]
const DEFAULT_PIN_OFFSET_TILES: float = 5.0

var state: State = State.CURSOR
var previous_state: State = State.CURSOR

var current_host_id: String = ""
var current_node_id: String = ""
var selected_routine: String = "hold"
var has_custom_pin: bool = false
var last_pin_pos: Vector2 = Vector2.ZERO

# Progression stats
var player_clearance: int = 0
var link_range_upgrades: int = 0
var ttl_upgrades: int = 0
var registered_models: Array[String] = ["cursor"]

# Spark TTL state
var max_ttl_ticks: int = BASE_TTL_TICKS
var ttl_ticks: int = BASE_TTL_TICKS
var pause_ttl_until_hijack: bool = false
var has_hijacked_in_room: bool = false

# Targeting state
var targeting_ticks_left: int = 0
var targeting_origin: Vector2 = Vector2.ZERO
var valid_targets: Array[Dictionary] = []
var selected_target_id: String = ""

# Transit state
var spark_pos: Vector2 = Vector2.ZERO
var transit_target_id: String = ""
var transit_target_pos: Vector2 = Vector2.ZERO
var transit_target_kind: String = "machine"
var transit_target_model: String = ""

func reset_for_room(p_pause_ttl_until_hijack: bool = false) -> void:
	pause_ttl_until_hijack = p_pause_ttl_until_hijack
	has_hijacked_in_room = (state == State.HOSTED or state == State.NODE_PILOT)
	has_custom_pin = false
	if state == State.TARGETING:
		cancel_targeting()

func recalculate_max_ttl() -> void:
	max_ttl_ticks = mini(MAX_TTL_CAP_TICKS, BASE_TTL_TICKS + ttl_upgrades * TTL_UPGRADE_TICKS)
	ttl_ticks = mini(ttl_ticks, max_ttl_ticks)

func refill_ttl() -> void:
	recalculate_max_ttl()
	ttl_ticks = max_ttl_ticks
	ttl_changed.emit(ttl_ticks, max_ttl_ticks)

func get_link_range_tiles() -> float:
	return minf(MAX_LINK_RANGE_TILES, BASE_LINK_RANGE_TILES + float(link_range_upgrades) * LINK_RANGE_UPGRADE_TILES)

func get_link_range_px() -> float:
	return get_link_range_tiles() * float(Grid.TILE_SIZE)

func get_time_scale() -> float:
	return TARGETING_TIME_SCALE if state == State.TARGETING else 1.0

func cycle_routine() -> String:
	var idx: int = ROUTINES.find(selected_routine)
	selected_routine = ROUTINES[(idx + 1) % ROUTINES.size()]
	routine_changed.emit(selected_routine)
	return selected_routine

func drop_pin(origin_pos: Vector2, facing: Vector2) -> Vector2:
	var dir: Vector2 = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	last_pin_pos = origin_pos + dir * (DEFAULT_PIN_OFFSET_TILES * float(Grid.TILE_SIZE))
	has_custom_pin = true
	pin_dropped.emit(last_pin_pos)
	return last_pin_pos

func get_effective_pin(park_pos: Vector2, facing: Vector2) -> Vector2:
	if has_custom_pin:
		return last_pin_pos
	var dir: Vector2 = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	return park_pos + dir * (DEFAULT_PIN_OFFSET_TILES * float(Grid.TILE_SIZE))

static func is_candidate_valid(candidate: Dictionary, origin_pos: Vector2, max_range_px: float, clearance: int) -> bool:
	if bool(candidate.get("is_immune_unit", false)) or bool(candidate.get("is_boss_body", false)):
		return false
	if bool(candidate.get("is_trapped", false)):
		return false
	if not bool(candidate.get("has_los", true)):
		return false
	var cand_state: String = str(candidate.get("state", "dormant"))
	if cand_state == "crashed":
		return false
	var cand_pos: Vector2 = candidate.get("pos", Vector2.ZERO) as Vector2
	if origin_pos.distance_to(cand_pos) > max_range_px:
		return false
	var req_clearance: int = int(candidate.get("clearance", 0))
	if req_clearance > clearance:
		return false
	var kind: String = str(candidate.get("kind", "machine"))
	if kind == "node":
		return true
	if cand_state == "dormant" or cand_state == "parked":
		return true
	if cand_state == "hostile":
		return bool(candidate.get("is_open", false))
	return false

func start_targeting(origin_pos: Vector2, candidates: Array[Dictionary], initial_aim: Vector2 = Vector2.ZERO) -> bool:
	if state != State.CURSOR and state != State.HOSTED and state != State.NODE_PILOT:
		return false
	previous_state = state
	targeting_origin = origin_pos
	targeting_ticks_left = TARGETING_MAX_TICKS
	_refresh_valid_targets(candidates)
	_set_state(State.TARGETING)
	select_target_by_aim(initial_aim)
	var ids: Array[String] = []
	for c: Dictionary in valid_targets:
		ids.append(str(c.get("id", "")))
	targeting_started.emit(ids, selected_target_id)
	return true

func _refresh_valid_targets(candidates: Array[Dictionary]) -> void:
	valid_targets.clear()
	var range_px: float = get_link_range_px()
	for c: Dictionary in candidates:
		var cand_id: String = str(c.get("id", ""))
		if cand_id.is_empty() or cand_id == current_host_id or cand_id == current_node_id:
			continue
		if is_candidate_valid(c, targeting_origin, range_px, player_clearance):
			valid_targets.append(c.duplicate())

func select_target_by_aim(aim_dir: Vector2) -> String:
	if valid_targets.is_empty():
		selected_target_id = ""
		return ""
	var best_id: String = str(valid_targets[0].get("id", ""))
	var best_score: float = -INF
	var has_aim: bool = aim_dir.length_squared() > 0.001
	var norm_aim: Vector2 = aim_dir.normalized() if has_aim else Vector2.ZERO

	for c: Dictionary in valid_targets:
		var cid: String = str(c.get("id", ""))
		var cpos: Vector2 = c.get("pos", Vector2.ZERO) as Vector2
		var diff: Vector2 = cpos - targeting_origin
		var dist: float = maxf(1.0, diff.length())
		var score: float = -dist
		if has_aim:
			var dot: float = norm_aim.dot(diff / dist)
			score = dot * 1000.0 - dist
		if score > best_score:
			best_score = score
			best_id = cid

	if selected_target_id != best_id:
		selected_target_id = best_id
		target_selected.emit(selected_target_id)
	return selected_target_id

func cancel_targeting() -> void:
	if state != State.TARGETING:
		return
	targeting_ticks_left = 0
	selected_target_id = ""
	valid_targets.clear()
	_set_state(previous_state)
	targeting_cancelled.emit()

func confirm_targeting(origin_pos: Vector2, facing: Vector2 = Vector2.DOWN) -> bool:
	if state != State.TARGETING or selected_target_id.is_empty():
		cancel_targeting()
		return false
	var chosen: Dictionary = {}
	for c: Dictionary in valid_targets:
		if str(c.get("id", "")) == selected_target_id:
			chosen = c
			break
	if chosen.is_empty():
		cancel_targeting()
		return false

	if previous_state == State.HOSTED and not current_host_id.is_empty():
		var pin_pos: Vector2 = get_effective_pin(origin_pos, facing)
		host_parked.emit(current_host_id, selected_routine, pin_pos)
		current_host_id = ""
	elif previous_state == State.NODE_PILOT and not current_node_id.is_empty():
		node_exited.emit(current_node_id)
		current_node_id = ""

	spark_pos = origin_pos
	transit_target_id = str(chosen.get("id", ""))
	transit_target_pos = chosen.get("pos", origin_pos) as Vector2
	transit_target_kind = str(chosen.get("kind", "machine"))
	transit_target_model = str(chosen.get("model", ""))
	targeting_ticks_left = 0
	valid_targets.clear()
	_set_state(State.TRANSIT)
	transit_started.emit(spark_pos, transit_target_id, transit_target_pos)
	return true

func step_targeting_tick(aim_dir: Vector2, confirm_pressed: bool, cancel_pressed: bool, origin_pos: Vector2, facing: Vector2 = Vector2.DOWN) -> void:
	if state != State.TARGETING:
		return
	if cancel_pressed:
		cancel_targeting()
		return
	if aim_dir != Vector2.ZERO:
		select_target_by_aim(aim_dir)
	if confirm_pressed:
		confirm_targeting(origin_pos, facing)
		return
	targeting_ticks_left -= 1
	if targeting_ticks_left <= 0:
		cancel_targeting()

func step_transit(delta: float, firewall_block_pos: Variant = null) -> void:
	if state != State.TRANSIT:
		return
	if firewall_block_pos is Vector2:
		spark_pos = firewall_block_pos as Vector2
		transit_target_id = ""
		has_hijacked_in_room = true
		_set_state(State.CURSOR)
		transit_blocked_by_firewall.emit(spark_pos)
		return

	var step_px: float = TRANSIT_SPEED_PX * delta
	spark_pos = spark_pos.move_toward(transit_target_pos, step_px)
	if spark_pos.distance_to(transit_target_pos) <= 0.5:
		spark_pos = transit_target_pos
		has_hijacked_in_room = true
		refill_ttl()
		if transit_target_kind == "node":
			current_node_id = transit_target_id
			_set_state(State.NODE_PILOT)
			node_seized.emit(current_node_id)
		else:
			current_host_id = transit_target_id
			_set_state(State.HOSTED)
			if not transit_target_model.is_empty() and not registered_models.has(transit_target_model):
				registered_models.append(transit_target_model)
				model_registered.emit(transit_target_model)
			host_seized.emit(current_host_id, transit_target_model)

func voluntary_eject(origin_pos: Vector2, facing: Vector2 = Vector2.DOWN) -> bool:
	if state == State.HOSTED and not current_host_id.is_empty():
		var old_id: String = current_host_id
		var pin_pos: Vector2 = get_effective_pin(origin_pos, facing)
		current_host_id = ""
		spark_pos = origin_pos
		refill_ttl()
		_set_state(State.CURSOR)
		host_parked.emit(old_id, selected_routine, pin_pos)
		ejected.emit(old_id, "voluntary")
		return true
	if state == State.NODE_PILOT and not current_node_id.is_empty():
		var old_node: String = current_node_id
		current_node_id = ""
		spark_pos = origin_pos
		refill_ttl()
		_set_state(State.CURSOR)
		node_exited.emit(old_node)
		ejected.emit(old_node, "voluntary")
		return true
	return false

func force_eject(origin_pos: Vector2, reason: String) -> bool:
	if state == State.TARGETING and previous_state == State.HOSTED:
		cancel_targeting()
	if state != State.HOSTED or current_host_id.is_empty():
		return false
	var old_id: String = current_host_id
	current_host_id = ""
	spark_pos = origin_pos
	refill_ttl()
	_set_state(State.CURSOR)
	ejected.emit(old_id, reason)
	return true

func step_cursor_ttl(is_in_safe_zone: bool, delta_ticks: int = 1) -> void:
	if state != State.CURSOR:
		return
	if is_in_safe_zone:
		return
	if pause_ttl_until_hijack and not has_hijacked_in_room:
		return
	if ttl_ticks > 0:
		ttl_ticks = maxi(0, ttl_ticks - delta_ticks)
		ttl_changed.emit(ttl_ticks, max_ttl_ticks)
		if ttl_ticks <= 0:
			reboot_triggered.emit("ttl_expired")

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	var old: State = state
	state = new_state
	state_changed.emit(old, new_state)
