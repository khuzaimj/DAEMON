class_name RangedAbilities
extends RefCounted

static func _spawn_projectile(machine: Machine) -> Projectile:
	var proj: Projectile = Projectile.new()
	var container: Node = machine.get_parent()
	if container != null:
		container.add_child(proj)
	return proj

static func start_projectile(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var speed_tiles: float = float(params.get("speed", 14.0))
	var range_tiles: float = float(params.get("range", 8.0))
	var damage: int = int(params.get("damage", 2))
	var speed_px: float = speed_tiles * float(Grid.TILE_SIZE)
	var range_px: float = range_tiles * float(Grid.TILE_SIZE)
	
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	var proj: Projectile = _spawn_projectile(machine)
	proj.setup(machine, norm_dir, speed_px, range_px, damage, "kinetic")
	proj.proj_color = Color(0.2, 0.9, 1.0) # Sentry blue bolt

static func start_overwatch(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	machine.facing = norm_dir
	# Overwatch sets up arc guard; fires instant bolt on activation
	start_projectile(machine, data, norm_dir)

static func start_overload_shot(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var speed_tiles: float = float(params.get("speed", 12.0))
	var range_tiles: float = float(params.get("range", 4.5))
	var damage: int = int(params.get("damage", 1))
	var status_sec: float = float(params.get("status_duration", 2.0))
	var status_ticks: int = AbilityMath.seconds_to_ticks(status_sec)
	
	var speed_px: float = speed_tiles * float(Grid.TILE_SIZE)
	var range_px: float = range_tiles * float(Grid.TILE_SIZE)
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	
	var proj: Projectile = _spawn_projectile(machine)
	proj.setup(machine, norm_dir, speed_px, range_px, damage, "electric")
	proj.status_on_hit = "overload"
	proj.status_duration_ticks = status_ticks
	proj.proj_color = Color(0.9, 0.9, 0.2) # Electric yellow bolt

static func start_harpoon(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var speed_tiles: float = float(params.get("speed", 15.0))
	var range_tiles: float = float(params.get("range", 6.0))
	var damage: int = int(params.get("damage", 1))
	
	var speed_px: float = speed_tiles * float(Grid.TILE_SIZE)
	var range_px: float = range_tiles * float(Grid.TILE_SIZE)
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	
	var proj: Projectile = _spawn_projectile(machine)
	proj.setup(machine, norm_dir, speed_px, range_px, damage, "kinetic")
	proj.knockback_force = -2.0 # Negative knockback pulls target toward machine (harpoon tether)
	proj.proj_color = Color(0.3, 0.8, 0.8) # Teal line/harpoon

static func start_throw_parcel(machine: Machine, data: Dictionary, dir: Vector2) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	var params: Dictionary = data.get("params", {}) as Dictionary
	var speed_tiles: float = float(params.get("speed", 10.0))
	var range_tiles: float = float(params.get("range", 5.0))
	var damage: int = int(params.get("damage", 2))
	
	var speed_px: float = speed_tiles * float(Grid.TILE_SIZE)
	var range_px: float = range_tiles * float(Grid.TILE_SIZE)
	var norm_dir: Vector2 = dir.normalized() if dir != Vector2.ZERO else machine.facing
	
	var proj: Projectile = _spawn_projectile(machine)
	proj.setup(machine, norm_dir, speed_px, range_px, damage, "kinetic")
	proj.proj_color = Color(0.9, 0.7, 0.3) # Parcel box amber
	proj.radius = 4.0
