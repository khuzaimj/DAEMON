class_name AbilityMath
extends RefCounted

const TPS: float = 60.0

static func seconds_to_ticks(seconds: float) -> int:
	return int(round(seconds * TPS))

static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / TPS

static func is_point_in_arc(origin: Vector2, facing: Vector2, target: Vector2, arc_degrees: float, radius: float) -> bool:
	var dist: float = origin.distance_to(target)
	if dist > radius:
		return false
	if dist <= 0.001:
		return true
	var dir_to_target: Vector2 = (target - origin).normalized()
	var norm_facing: Vector2 = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	var angle_diff: float = absf(norm_facing.angle_to(dir_to_target))
	var half_arc_rad: float = deg_to_rad(arc_degrees * 0.5)
	return angle_diff <= half_arc_rad

static func is_point_in_cone(origin: Vector2, facing: Vector2, target: Vector2, cone_degrees: float, length: float) -> bool:
	return is_point_in_arc(origin, facing, target, cone_degrees, length)

static func calculate_knockback(source_pos: Vector2, target_pos: Vector2, force: float) -> Vector2:
	var diff: Vector2 = target_pos - source_pos
	if diff.length_squared() < 0.0001:
		return Vector2.RIGHT * force
	return diff.normalized() * force

static func snap_to_8_way(vector: Vector2, default_facing: Vector2 = Vector2.DOWN) -> Vector2:
	if vector == Vector2.ZERO:
		return default_facing
	var angle: float = vector.angle() # radians from -PI to PI
	var octant: int = int(round(8.0 * angle / (2.0 * PI))) % 8
	if octant < 0:
		octant += 8
	match octant:
		0: return Vector2.RIGHT
		1: return Vector2(1, 1).normalized()
		2: return Vector2.DOWN
		3: return Vector2(-1, 1).normalized()
		4: return Vector2.LEFT
		5: return Vector2(-1, -1).normalized()
		6: return Vector2.UP
		7: return Vector2(1, -1).normalized()
		_: return Vector2.DOWN

static func facing_to_sheet_direction(facing: Vector2) -> String:
	# §1.11: Three facings are drawn (down, up, side). Left is the side sheet flipped at runtime.
	if absf(facing.y) > absf(facing.x):
		return "down" if facing.y > 0.0 else "up"
	return "side"
