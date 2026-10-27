class_name MovementAbilities
extends RefCounted

static func start_charge_dash(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var speed_tiles: float = float(params.get("speed", 11.0))
	var distance_tiles: float = float(params.get("distance", 5.0))
	var speed_px: float = speed_tiles * float(Grid.TILE_SIZE)
	var duration_sec: float = distance_tiles / speed_tiles if speed_tiles > 0.0 else 0.4
	var ticks: int = AbilityMath.seconds_to_ticks(duration_sec)
	
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	machine.start_dash(norm_dir, speed_px, ticks, true, false, false)

static func start_dash(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var distance_tiles: float = float(params.get("distance", 3.0))
	var duration_sec: float = float(params.get("duration", 0.18))
	var speed_tiles: float = distance_tiles / duration_sec if duration_sec > 0.0 else 16.0
	var speed_px: float = speed_tiles * float(Grid.TILE_SIZE)
	var ticks: int = AbilityMath.seconds_to_ticks(duration_sec)
	
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	# Dash grants invulnerability for its duration and bypasses layer 10 pit
	machine.start_dash(norm_dir, speed_px, ticks, false, true, true)

static func start_cling(machine: Machine, data: Dictionary, _dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var duration_sec: float = float(params.get("duration", 1.0))
	var ticks: int = AbilityMath.seconds_to_ticks(duration_sec)
	machine.state.apply_status("cling", ticks)
