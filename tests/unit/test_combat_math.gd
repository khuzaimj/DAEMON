extends GutTest

func test_basic_damage_calculation() -> void:
	var body: Dictionary = { "id": "janitor", "resist": {}, "vulnerable": {} }
	var passives: Array[String] = []
	var dmg: int = CombatMath.calculate_damage(10, "kinetic", body, passives)
	assert_eq(dmg, 10, "Base kinetic damage without modifiers should equal base amount")

func test_resistance_and_vulnerability_multipliers() -> void:
	# Welder thermal immune (multiplier 0.0)
	var welder: Dictionary = { "id": "welder", "resist": { "thermal": 0.0 }, "vulnerable": { "kinetic": 1.2 } }
	var dmg_fire: int = CombatMath.calculate_damage(10, "thermal", welder, [])
	assert_eq(dmg_fire, 0, "Welder thermal resistance 0.0 should negate thermal damage")

	var dmg_phys: int = CombatMath.calculate_damage(10, "kinetic", welder, [])
	assert_eq(dmg_phys, 12, "Welder kinetic vulnerability 1.2 should scale 10 to 12")

	# Diver thermal resist 0.5, electric vulnerable 1.5
	var diver: Dictionary = { "id": "diver", "resist": { "thermal": 0.5 }, "vulnerable": { "electric": 1.5 } }
	assert_eq(CombatMath.calculate_damage(10, "thermal", diver, []), 5, "Diver thermal resistance 0.5 should halve damage")
	assert_eq(CombatMath.calculate_damage(10, "electric", diver, []), 15, "Diver electric vulnerability 1.5 should increase damage")

func test_passive_immunities() -> void:
	var body: Dictionary = {}
	assert_eq(CombatMath.calculate_damage(10, "thermal", body, ["fire_immune"]), 0, "fire_immune passive negates thermal")
	assert_eq(CombatMath.calculate_damage(10, "electric", body, ["insulated"]), 0, "insulated passive negates electric")
	assert_eq(CombatMath.calculate_damage(10, "decay", body, ["bitrot_immune"]), 0, "bitrot_immune passive negates decay")

func test_sentry_armored_front_mitigation() -> void:
	var sentry_body: Dictionary = { "resist": { "kinetic": 1.0 } }
	var sentry_passives: Array[String] = ["armored_front"]
	var target_facing: Vector2 = Vector2.UP # Facing North

	# 1. Frontal attack: attacker is to the North, firing South (impact_dir = Vector2.DOWN)
	# impact_dir is DOWN. -impact_dir is UP. Aligning with target_facing (UP) -> frontal hit!
	var frontal_dir: Vector2 = Vector2.DOWN
	assert_true(CombatMath.is_frontal_hit(target_facing, frontal_dir), "Head-on collision should count as frontal hit")
	var frontal_dmg: int = CombatMath.calculate_damage(10, "kinetic", sentry_body, sentry_passives, target_facing, frontal_dir)
	assert_eq(frontal_dmg, 5, "Sentry armored_front should reduce frontal damage by 50%")

	# 2. Rear attack: attacker is to the South, firing North (impact_dir = Vector2.UP)
	# -impact_dir is DOWN. Opposite to target_facing (UP) -> rear hit!
	var rear_dir: Vector2 = Vector2.UP
	assert_false(CombatMath.is_frontal_hit(target_facing, rear_dir), "Rear collision should not count as frontal hit")
	var rear_dmg: int = CombatMath.calculate_damage(10, "kinetic", sentry_body, sentry_passives, target_facing, rear_dir)
	assert_eq(rear_dmg, 10, "Sentry armored_front should not reduce rear damage")

func test_electric_heat_calculation() -> void:
	var heat: float = CombatMath.calculate_electric_heat(2)
	assert_eq(heat, 40.0, "2 electric damage should add 40.0 Heat (20 heat per damage)")

func test_knockback_calculation() -> void:
	var dir: Vector2 = Vector2.RIGHT
	var kb_normal: Vector2 = CombatMath.calculate_knockback(dir, 100.0, 1, [])
	assert_eq(kb_normal, Vector2(100.0, 0.0), "Weight 1 normal knockback")

	var kb_heavy: Vector2 = CombatMath.calculate_knockback(dir, 100.0, 2, [])
	assert_eq(kb_heavy, Vector2(50.0, 0.0), "Weight 2 halves knockback")

	var kb_resist: Vector2 = CombatMath.calculate_knockback(dir, 100.0, 1, ["knockback_resist"])
	assert_eq(kb_resist, Vector2.ZERO, "knockback_resist passive negates knockback")
