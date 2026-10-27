extends GutTest

func test_sizes_data_schema() -> void:
	var file: FileAccess = FileAccess.open("res://data/sizes.json", FileAccess.READ)
	assert_not_null(file, "sizes.json must exist")
	var json: JSON = JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "sizes.json must be valid JSON")
	var data: Dictionary = json.data as Dictionary
	var errors: Array[String] = Schema.validate_sizes(data, "sizes.json")
	assert_eq(errors.size(), 0, "sizes.json should have 0 schema errors")

func test_sample_enemy_and_ai_schemas() -> void:
	# Test rogue_janitor.json
	var enemy_file: FileAccess = FileAccess.open("res://data/enemies/rogue_janitor.json", FileAccess.READ)
	assert_not_null(enemy_file, "rogue_janitor.json must exist")
	var enemy_json: JSON = JSON.new()
	assert_eq(enemy_json.parse(enemy_file.get_as_text()), OK)
	var enemy_data: Dictionary = enemy_json.data as Dictionary
	var enemy_errors: Array[String] = Schema.validate_enemy(enemy_data, "rogue_janitor.json")
	assert_eq(enemy_errors.size(), 0, "rogue_janitor.json should have 0 schema errors")
	
	# Test melee_swarmer.json
	var ai_file: FileAccess = FileAccess.open("res://data/ai/melee_swarmer.json", FileAccess.READ)
	assert_not_null(ai_file, "melee_swarmer.json must exist")
	var ai_json: JSON = JSON.new()
	assert_eq(ai_json.parse(ai_file.get_as_text()), OK)
	var ai_data: Dictionary = ai_json.data as Dictionary
	var ai_errors: Array[String] = Schema.validate_ai_preset(ai_data, "melee_swarmer.json")
	assert_eq(ai_errors.size(), 0, "melee_swarmer.json should have 0 schema errors")

func test_body_and_ability_schema_validation_rules() -> void:
	# Test valid body schema
	var valid_body: Dictionary = {
		"id": "test_bot",
		"name": "Test Bot",
		"size": "M",
		"weight": 1,
		"medium": ["ground"],
		"speed": 3.0,
		"integrity": 10,
		"heat_max": 100,
		"heat_cooldown": 20,
		"primary": "test_sweep",
		"secondary": "",
		"passives": [],
		"tags": ["machine"],
		"sprite": "test",
		"clearance": 0,
		"garage_cost": 20,
		"unlock_zone": "boot"
	}
	var b_errs: Array[String] = Schema.validate_body(valid_body)
	assert_eq(b_errs.size(), 0, "Valid body should have 0 errors")
	
	# Test invalid body schema (missing key and bad size)
	var bad_body: Dictionary = {
		"id": "BadIDWithCaps",
		"size": "gigantic"
	}
	var bad_errs: Array[String] = Schema.validate_body(bad_body)
	assert_true(bad_errs.size() > 0, "Bad body must produce errors")
	
	# Test valid ability schema
	var valid_ability: Dictionary = {
		"id": "test_sweep",
		"kind": "melee_arc",
		"heat_cost": 15,
		"cooldown": 0.5,
		"windup": 0.1,
		"params": { "arc": 90.0, "radius": 24.0 },
		"sfx": "sweep"
	}
	var a_errs: Array[String] = Schema.validate_ability(valid_ability)
	assert_eq(a_errs.size(), 0, "Valid ability should have 0 errors")
	
	# Test invalid ability kind
	var bad_ability: Dictionary = {
		"id": "bad_ab",
		"kind": "teleport_nuke",
		"heat_cost": 0,
		"cooldown": 1,
		"windup": 0,
		"params": {},
		"sfx": "none"
	}
	var bad_a_errs: Array[String] = Schema.validate_ability(bad_ability)
	assert_true(bad_a_errs.size() > 0, "Unknown ability kind must produce error")
