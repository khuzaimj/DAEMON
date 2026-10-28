class_name CombatMath
extends RefCounted

const OVERLOAD_DURATION_TICKS: int = 120 # 2.0s stun + Open (at 60 TPS)
const STAGGER_DURATION_TICKS: int = 15   # 0.25s interrupt
const BURN_DURATION_TICKS: int = 180     # 3.0s DoT
const INVULNERABILITY_TICKS: int = 30    # 0.5s invulnerability

## Checks if an incoming attack hits the front arc of target_facing (within 60 degrees).
static func is_frontal_hit(target_facing: Vector2, impact_dir: Vector2, threshold_cos: float = 0.5) -> bool:
	if target_facing == Vector2.ZERO or impact_dir == Vector2.ZERO:
		return false
	# impact_dir points towards the target.
	# A head-on impact means -impact_dir aligns with target_facing.
	var dot_prod: float = target_facing.normalized().dot(-impact_dir.normalized())
	return dot_prod >= threshold_cos

## Calculates effective damage after resistance, vulnerability, and passives.
static func calculate_damage(
	base_damage: int,
	damage_type: String,
	body_data: Dictionary,
	passives: Array[String],
	target_facing: Vector2 = Vector2.ZERO,
	impact_dir: Vector2 = Vector2.ZERO
) -> int:
	if base_damage <= 0:
		return 0

	# 1. Passive immunities
	if damage_type == "thermal" and passives.has("fire_immune"):
		return 0
	if damage_type == "electric" and passives.has("insulated"):
		return 0
	if damage_type == "decay" and passives.has("bitrot_immune"):
		return 0

	var multiplier: float = 1.0

	# 2. Resistances
	if body_data.has("resist"):
		var r: Variant = body_data["resist"]
		if r is Dictionary:
			if (r as Dictionary).has(damage_type):
				multiplier *= float((r as Dictionary)[damage_type])
		elif r is Array:
			if (r as Array).has(damage_type):
				multiplier *= 0.5

	# 3. Vulnerabilities
	if body_data.has("vulnerable"):
		var v: Variant = body_data["vulnerable"]
		if v is Dictionary:
			if (v as Dictionary).has(damage_type):
				multiplier *= float((v as Dictionary)[damage_type])
		elif v is Array:
			if (v as Array).has(damage_type):
				multiplier *= 1.5

	var final_dmg: float = float(base_damage) * multiplier

	# 4. Sentry armored_front passive (reduces frontal attacks by 50%)
	if passives.has("armored_front") and is_frontal_hit(target_facing, impact_dir):
		final_dmg *= 0.5

	var result: int = int(round(final_dmg))
	if multiplier > 0.0 and final_dmg > 0.0 and result == 0:
		result = 1
	return maxi(0, result)

## Electric hits add Heat per §1.9.
static func calculate_electric_heat(base_damage: int, heat_per_dmg: float = 20.0) -> float:
	return float(maxi(1, base_damage)) * heat_per_dmg

## Calculates knockback vector scaled by target weight and passives.
static func calculate_knockback(
	impact_dir: Vector2,
	force_px: float,
	target_weight: int,
	passives: Array[String] = []
) -> Vector2:
	if passives.has("knockback_resist") or passives.has("anchored"):
		return Vector2.ZERO
	if impact_dir == Vector2.ZERO or force_px <= 0.0:
		return Vector2.ZERO
	var w: float = maxf(1.0, float(target_weight))
	return impact_dir.normalized() * (force_px / w)
