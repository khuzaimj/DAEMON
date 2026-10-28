class_name BodyState
extends RefCounted

signal heat_changed(new_heat: float, max_heat: float)
signal integrity_changed(new_integrity: int, max_integrity: int)
signal crashed()
signal overheated()
signal recovered_from_overheat()
signal status_applied(status_name: String, duration_ticks: int)
signal status_removed(status_name: String)

var current_integrity: int = 10
var max_integrity: int = 10
var current_heat: float = 0.0
var max_heat: float = 100.0
var cooling_rate: float = 20.0 # Heat cooled per second at 60 tps
var open_threshold: float = 0.35

var is_crashed: bool = false
var is_overheated: bool = false
var overheat_timer_ticks: int = 0
var invulnerability_ticks: int = 0

var statuses: Dictionary = {} # String -> int (ticks remaining)
var cooldowns: Dictionary = {} # String -> int (ticks remaining)
var burn_tick_counter: int = 0

func setup_from_dict(data: Dictionary) -> void:
	max_integrity = int(data.get("integrity", 10))
	current_integrity = max_integrity
	max_heat = float(data.get("heat_max", 100.0))
	current_heat = 0.0
	cooling_rate = float(data.get("heat_cooldown", 20.0))
	is_crashed = false
	is_overheated = false
	overheat_timer_ticks = 0
	invulnerability_ticks = 0
	statuses.clear()
	cooldowns.clear()

func tick(delta_ticks: int = 1) -> void:
	# 1. Heat decay
	if current_heat > 0.0:
		var cool_step: float = (cooling_rate / 60.0) * float(delta_ticks)
		current_heat = maxf(0.0, current_heat - cool_step)
		heat_changed.emit(current_heat, max_heat)

	# 2. Overheat timer
	if is_overheated:
		overheat_timer_ticks -= delta_ticks
		if overheat_timer_ticks <= 0:
			is_overheated = false
			overheat_timer_ticks = 0
			recovered_from_overheat.emit()

	# 3. Invulnerability timer
	if invulnerability_ticks > 0:
		invulnerability_ticks = maxi(0, invulnerability_ticks - delta_ticks)

	# 4. Status effects execution (e.g. burn damage: 1 dmg per 30 ticks = 0.5s)
	if has_status("burn") and not is_crashed:
		burn_tick_counter += delta_ticks
		if burn_tick_counter >= 30:
			burn_tick_counter = 0
			take_damage(1, "thermal", true)
	else:
		burn_tick_counter = 0

	# 5. Status timers decrement & expiration
	var expired_statuses: Array[String] = []
	for status_name_variant: Variant in statuses.keys():
		var status_name: String = str(status_name_variant)
		var ticks_left: int = int(statuses[status_name]) - delta_ticks
		if ticks_left <= 0:
			expired_statuses.append(status_name)
		else:
			statuses[status_name] = ticks_left

	for status_name: String in expired_statuses:
		statuses.erase(status_name)
		status_removed.emit(status_name)

	# 6. Ability cooldowns
	var expired_cooldowns: Array[String] = []
	for slot_variant: Variant in cooldowns.keys():
		var slot: String = str(slot_variant)
		var cd_ticks_left: int = int(cooldowns[slot]) - delta_ticks
		if cd_ticks_left <= 0:
			expired_cooldowns.append(slot)
		else:
			cooldowns[slot] = cd_ticks_left

	for slot: String in expired_cooldowns:
		cooldowns.erase(slot)

func add_heat(amount: float) -> void:
	if is_crashed:
		return
	current_heat = minf(max_heat, current_heat + amount)
	heat_changed.emit(current_heat, max_heat)
	if current_heat >= max_heat and not is_overheated:
		is_overheated = true
		overheat_timer_ticks = 180 # 3.0 seconds lockout (180 ticks at 60 TPS)
		overheated.emit()

func take_damage(amount: int, _damage_type: String = "kinetic", ignore_invuln: bool = false) -> bool:
	if is_crashed:
		return false
	if invulnerability_ticks > 0 and not ignore_invuln:
		return false

	current_integrity = maxi(0, current_integrity - amount)
	integrity_changed.emit(current_integrity, max_integrity)

	if not ignore_invuln:
		invulnerability_ticks = 30 # 0.5s invulnerability

	if current_integrity <= 0 and not is_crashed:
		is_crashed = true
		crashed.emit()

	return true

func repair(amount: int) -> void:
	if max_integrity <= 0:
		return
	current_integrity = mini(max_integrity, current_integrity + amount)
	integrity_changed.emit(current_integrity, max_integrity)
	if current_integrity > 0 and is_crashed:
		is_crashed = false

func apply_status(status_name: String, duration_ticks: int) -> void:
	statuses[status_name] = duration_ticks
	status_applied.emit(status_name, duration_ticks)

func remove_status(status_name: String) -> void:
	if statuses.has(status_name):
		statuses.erase(status_name)
		status_removed.emit(status_name)

func has_status(status_name: String) -> bool:
	return statuses.has(status_name)

func get_status_duration(status_name: String) -> int:
	return int(statuses.get(status_name, 0))

func is_open() -> bool:
	if has_status("overload"):
		return true
	if max_integrity > 0 and float(current_integrity) / float(max_integrity) <= open_threshold:
		return true
	return false

func can_act() -> bool:
	if is_crashed or is_overheated:
		return false
	if has_status("stun") or has_status("overload") or has_status("stagger"):
		return false
	return true

func set_cooldown(slot: String, duration_ticks: int) -> void:
	cooldowns[slot] = duration_ticks

func get_cooldown(slot: String) -> int:
	return int(cooldowns.get(slot, 0))

func is_cooling_down(slot: String) -> bool:
	return get_cooldown(slot) > 0
